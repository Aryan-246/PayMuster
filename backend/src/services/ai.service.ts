import { GoogleGenAI, Type, type Schema } from '@google/genai';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import {
  adminAiProviderResponseSchema,
} from '../schemas/admin-ai.schema.js';

const SYSTEM_ENTITY_ID = '00000000-0000-0000-0000-000000000000';
const PROVIDER_NAME = 'gemini';
const AI_ENTITY_TYPE = 'AdminAiAnalysis';

export interface AdminAiOperationalContext {
  users: number;
  companies: number;
  sites: number;
  attendance: number;
  payroll: number;
  pendingOwnerRequests: number;
  blockedUsers: number;
}

export interface AdminAiRequest {
  prompt: string;
  actorId: string;
  role?: string;
  orgId?: string | null;
  requestId?: string;
  ipAddress?: string;
  userAgent?: string;
}

export interface AdminAiProviderInput {
  prompt: string;
  context: AdminAiOperationalContext;
}

export interface AdminAiProvider {
  generateAnalysis(input: AdminAiProviderInput): Promise<unknown>;
}

export interface AdminAiAuditRecord {
  status: 'COMPLETED' | 'UNAVAILABLE' | 'TIMEOUT' | 'FAILED' | 'INVALID_RESPONSE';
  provider: string;
  model: string;
  promptLength: number;
  durationMs: number;
  context?: AdminAiOperationalContext;
  errorCode?: string;
}

export interface AiServiceDependencies {
  provider?: AdminAiProvider;
  contextReader?: (request: AdminAiRequest) => Promise<AdminAiOperationalContext>;
  auditWriter?: (input: {
    actorId: string;
    orgId?: string | null;
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
    record: AdminAiAuditRecord;
  }) => Promise<void>;
  timeoutMs?: number;
  model?: string;
  apiKey?: string | null;
}

const providerResponseSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    message: {
      type: Type.STRING,
      description: 'A concise analysis of the administrator request. Do not provide executable actions.',
    },
  },
  required: ['message'],
};

const operationalContextReader = async (request: AdminAiRequest): Promise<AdminAiOperationalContext> => {
  const globalScope = request.role === 'SUPER_ADMIN' && !request.orgId;
  const orgId = globalScope ? undefined : request.orgId ?? '__missing_org__';
  const [users, companies, sites, attendance, payroll, pendingOwnerRequests, blockedUsers] =
    await Promise.all([
      prisma.user.count({ where: { deletedAt: null, ...(orgId ? { orgId } : {}) } }),
      prisma.organization.count({ where: { deletedAt: null, ...(orgId ? { id: orgId } : {}) } }),
      prisma.site.count({ where: { deletedAt: null, ...(orgId ? { orgId } : {}) } }),
      prisma.attendanceRecord.count({ where: { deletedAt: null, ...(orgId ? { orgId } : {}) } }),
      prisma.payRun.count({ where: { deletedAt: null, ...(orgId ? { orgId } : {}) } }),
      globalScope
        ? prisma.ownerRequest.count({ where: { status: 'PENDING', deletedAt: null } })
        : Promise.resolve(0),
      prisma.user.count({ where: { isDisabled: true, deletedAt: null, ...(orgId ? { orgId } : {}) } }),
    ]);

  return {
    users,
    companies,
    sites,
    attendance,
    payroll,
    pendingOwnerRequests,
    blockedUsers,
  };
};

const defaultAuditWriter: NonNullable<AiServiceDependencies['auditWriter']> = async ({
  actorId,
  orgId,
  requestId,
  ipAddress,
  userAgent,
  record,
}) => {
  await prisma.auditLog.create({
    data: {
      action: 'UPDATE',
      entityType: AI_ENTITY_TYPE,
      entityId: SYSTEM_ENTITY_ID,
      userId: actorId,
      orgId: orgId ?? null,
      requestId,
      ipAddress,
      userAgent,
      changes: {
        status: record.status,
        provider: record.provider,
        model: record.model,
        promptLength: record.promptLength,
        durationMs: record.durationMs,
        ...(record.context && {
          context: {
            users: record.context.users,
            companies: record.context.companies,
            sites: record.context.sites,
            attendance: record.context.attendance,
            payroll: record.context.payroll,
            pendingOwnerRequests: record.context.pendingOwnerRequests,
            blockedUsers: record.context.blockedUsers,
          },
        }),
        ...(record.errorCode && { errorCode: record.errorCode }),
      },
    },
  });
};

class GeminiAiProvider implements AdminAiProvider {
  private readonly ai: GoogleGenAI;
  private readonly model: string;

  constructor(apiKey: string, model: string) {
    this.ai = new GoogleGenAI({ apiKey });
    this.model = model;
  }

  async generateAnalysis(input: AdminAiProviderInput): Promise<unknown> {
    const response = await this.ai.models.generateContent({
      model: this.model,
      contents: JSON.stringify({
        prompt: input.prompt,
        operationalContext: input.context,
      }),
      config: {
        systemInstruction: `
You are the PayMuster Super Admin analysis assistant.
Provide analysis only. Never execute, recommend as an executable command, or format any state-changing action.
Never output proposals, action names, target IDs, SQL, shell commands, URLs, credentials, or personal data.
Use only the bounded aggregate operational context supplied by the backend.
If the request asks to change data or perform an operation, explain the relevant risk and direct the administrator to the existing reviewed Admin workflow.
Return JSON with exactly one field: message.
        `.trim(),
        responseMimeType: 'application/json',
        responseSchema: providerResponseSchema,
        temperature: 0.2,
      },
    });

    return response.text || '{}';
  }
}

export class AiService {
  private readonly provider?: AdminAiProvider;
  private readonly contextReader: (request: AdminAiRequest) => Promise<AdminAiOperationalContext>;
  private readonly auditWriter: NonNullable<AiServiceDependencies['auditWriter']>;
  private readonly timeoutMs: number;
  private readonly model: string;
  private readonly apiKey?: string;

  constructor(dependencies: AiServiceDependencies = {}) {
    this.provider = dependencies.provider;
    this.contextReader = dependencies.contextReader ?? operationalContextReader;
    this.auditWriter = dependencies.auditWriter ?? defaultAuditWriter;
    this.timeoutMs = dependencies.timeoutMs ?? config.geminiTimeoutMs;
    this.model = dependencies.model ?? config.geminiModel;
    this.apiKey = dependencies.apiKey === undefined
      ? config.geminiApiKey
      : dependencies.apiKey ?? undefined;
  }

  async processChat(request: AdminAiRequest) {
    const startedAt = Date.now();
    const provider = this.provider ?? (this.apiKey
      ? new GeminiAiProvider(this.apiKey, this.model)
      : undefined);

    if (!provider) {
      await this.writeAudit(request, {
        status: 'UNAVAILABLE',
        provider: PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: 'AI_UNAVAILABLE',
      });
      throw new AppError(
        'AI_UNAVAILABLE',
        'AI analysis is currently unavailable.',
        503,
        { retryAfterSeconds: 60 },
      );
    }

    let context: AdminAiOperationalContext;
    try {
      context = await this.contextReader(request);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('AI operational context could not be read', {
        error: message,
        requestId: request.requestId,
      });
      await this.writeAudit(request, {
        status: 'FAILED',
        provider: this.provider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: 'AI_CONTEXT_ERROR',
      });
      throw new AppError(
        'AI_CONTEXT_ERROR',
        'Operational context could not be prepared for AI analysis.',
        500,
      );
    }

    let rawResponse: unknown;
    try {
      rawResponse = await this.withTimeout(
        provider.generateAnalysis({ prompt: request.prompt, context }),
      );
    } catch (error) {
      const appError = this.classifyProviderError(error);
      await this.writeAudit(request, {
        status: appError.code === 'AI_TIMEOUT' ? 'TIMEOUT' : 'FAILED',
        provider: this.provider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        context,
        errorCode: appError.code,
      });
      throw appError;
    }

    const parsed = adminAiProviderResponseSchema.safeParse(
      this.parseProviderResponse(rawResponse),
    );
    if (!parsed.success) {
      logger.warn('AI provider returned an invalid analysis response', {
        issues: parsed.error.issues,
        requestId: request.requestId,
      });
      await this.writeAudit(request, {
        status: 'INVALID_RESPONSE',
        provider: this.provider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        context,
        errorCode: 'AI_INVALID_RESPONSE',
      });
      throw new AppError(
        'AI_INVALID_RESPONSE',
        'The AI provider returned an invalid analysis response.',
        502,
      );
    }

    const result = {
      message: parsed.data.message,
      provider: this.provider ? 'injected' : PROVIDER_NAME,
      model: this.model,
      generatedAt: new Date().toISOString(),
      scope: context,
    };

    await this.writeAudit(request, {
      status: 'COMPLETED',
      provider: result.provider,
      model: this.model,
      promptLength: request.prompt.length,
      durationMs: Date.now() - startedAt,
      context,
    });

    return result;
  }

  async processFoundation(
    operation: 'ANALYZE' | 'SUMMARY' | 'INSIGHTS' | 'QUERY',
    request: AdminAiRequest,
  ) {
    const result = await this.processChat({
      ...request,
      prompt: `[${operation}] ${request.prompt}`,
    });
    return {
      analysis: result.message,
      recommendation: null,
      proposal: null,
      confidence: null,
      metadata: {
        operation,
        provider: result.provider,
        model: result.model,
        generatedAt: result.generatedAt,
        scope: result.scope,
        mutationsAllowed: false,
      },
    };
  }

  private async withTimeout<T>(promise: Promise<T>): Promise<T> {
    let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new AppError(
          'AI_TIMEOUT',
          'AI analysis timed out. Please try again.',
          504,
          { retryAfterSeconds: 5 },
        ));
      }, this.timeoutMs);
    });

    try {
      return await Promise.race([promise, timeout]);
    } finally {
      if (timeoutHandle) {
        clearTimeout(timeoutHandle);
      }
    }
  }

  private parseProviderResponse(response: unknown): unknown {
    if (typeof response !== 'string') {
      return response;
    }

    try {
      return JSON.parse(response);
    } catch {
      return undefined;
    }
  }

  private classifyProviderError(error: unknown): AppError {
    if (error instanceof AppError) {
      return error;
    }

    const message = error instanceof Error ? error.message : String(error);
    logger.error('AI provider request failed', { error: message });
    return new AppError(
      'AI_PROCESSING_ERROR',
      'AI analysis could not be completed.',
      502,
    );
  }

  private async writeAudit(request: AdminAiRequest, record: AdminAiAuditRecord) {
    try {
      await this.auditWriter({
        actorId: request.actorId,
        orgId: request.orgId,
        requestId: request.requestId,
        ipAddress: request.ipAddress,
        userAgent: request.userAgent,
        record,
      });
    } catch (error) {
      logger.error('AI analysis audit write failed', {
        error: error instanceof Error ? error.message : String(error),
        requestId: request.requestId,
      });
      throw new AppError(
        'AI_AUDIT_ERROR',
        'AI analysis evidence could not be recorded.',
        500,
      );
    }
  }
}

export const aiService = new AiService();
