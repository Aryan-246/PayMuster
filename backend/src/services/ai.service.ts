import { randomUUID } from 'node:crypto';
import { GoogleGenAI, Type, type Schema } from '@google/genai';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { adminAiProviderResponseSchema } from '../schemas/admin-ai.schema.js';
import {
    adminAiToolRegistry,
    AI_TOOL_DECLARATIONS,
    isActionTool,
    isReadTool,
    type AiActionOperation,
    type AiActionResolution,
    type AiEntity,
    type AiToolDeclaration,
    type AiToolResult,
} from './admin-ai-tools.js';

// Re-exported so callers/tests can consume the shared tool-contract types from
// the AI service module (single import surface for the admin assistant).
export type { AiActionResolution, AiToolResult } from './admin-ai-tools.js';
import { subscriptionService } from './subscription.service.js';
import { adminService } from './admin.service.js';
import { recordProviderSuccess } from '../providers/usage-tracker.js';

const SYSTEM_ENTITY_ID = '00000000-0000-0000-0000-000000000000';
const PROVIDER_NAME = 'gemini';
const AI_ENTITY_TYPE = 'AdminAiAnalysis';

// Agentic-loop bounds. Each provider call is bounded by the per-call timeout;
// the whole request (every round-trip + tool execution) by the overall
// deadline. MAX_TOOL_ROUNDS caps the loop even when calls are fast.
const MAX_TOOL_ROUNDS = 3;
const CONFIRMATION_TTL_MS = 10 * 60 * 1000;

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
  /** Single-use token from a prior CONFIRMATION_REQUIRED response. */
  confirmationToken?: string;
}

// ---------------------------------------------------------------------------
// Legacy analysis pipeline (foundation AI, member scope) — kept intact.
// ---------------------------------------------------------------------------

export interface AdminAiProviderInput {
  prompt: string;
  context: AdminAiOperationalContext;
}

export interface AdminAiProvider {
  generateAnalysis(input: AdminAiProviderInput): Promise<unknown>;
}

// ---------------------------------------------------------------------------
// Admin assistant pipeline (tool-calling, SUPER_ADMIN scope).
// ---------------------------------------------------------------------------

export interface AdminAiFunctionCall {
  name: string;
  args: Record<string, unknown>;
}

export interface AdminAiChatMessage {
  role: 'user' | 'model' | 'tool';
  text?: string;
  functionCalls?: AdminAiFunctionCall[];
  functionResponses?: Array<{ name: string; response: unknown }>;
  /**
   * Raw model parts from the provider (including Gemini's thoughtSignature on
   * functionCall parts). Gemini 3.x rejects a replayed model turn whose
   * functionCall parts are missing the signature they were returned with, so
   * the original parts must be echoed back verbatim.
   */
  parts?: unknown[];
}

export interface AdminAiChatProvider {
  chat(input: {
    systemInstruction: string;
    tools: AiToolDeclaration[];
    messages: AdminAiChatMessage[];
  }): Promise<{ text?: string | null; functionCalls?: AdminAiFunctionCall[]; parts?: unknown[] }>;
}

export interface AdminAiConfirmation {
  operation: AiActionOperation;
  target: AiActionResolution['target'];
  currentState: Record<string, unknown>;
  consequences: string;
  expiresAt: string;
  token: string;
}

export interface AdminAiChatResult {
  message: string;
  intent:
    | 'ANSWER'
    | 'CONFIRMATION_REQUIRED'
    | 'ACTION_EXECUTED'
    | 'DATA_FALLBACK'
    | 'REFUSED';
  provider: string;
  model: string;
  generatedAt: string;
  toolCalls: Array<{ name: string; args: Record<string, unknown>; summary: string }>;
  entities: AiEntity[];
  metrics: Record<string, number> | null;
  contextUsed: Record<string, number> | null;
  confirmation?: AdminAiConfirmation;
  executedAction?: {
    operation: AiActionOperation;
    targetId: string;
    targetName: string | null;
    status: string;
    result: unknown;
  };
  degraded: boolean;
  durationMs: number;
}

export interface AdminAiAuditRecord {
  status:
    | 'COMPLETED'
    | 'UNAVAILABLE'
    | 'TIMEOUT'
    | 'FAILED'
    | 'INVALID_RESPONSE'
    | 'CONFIRMATION_REQUIRED'
    | 'ACTION_EXECUTED'
    | 'ACTION_REJECTED';
  provider: string;
  model: string;
  promptLength: number;
  durationMs: number;
  context?: AdminAiOperationalContext;
  errorCode?: string;
  detail?: Record<string, string | number | boolean | null | Array<string | number | boolean | null>>;
}

export interface AiServiceDependencies {
  provider?: AdminAiProvider;
  chatProvider?: AdminAiChatProvider;
  contextReader?: (request: AdminAiRequest) => Promise<AdminAiOperationalContext>;
  auditWriter?: (input: {
    actorId: string;
    orgId?: string | null;
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
    record: AdminAiAuditRecord;
  }) => Promise<void>;
  toolRegistry?: {
    execute(name: string, args: Record<string, unknown>): Promise<AiToolResult>;
    resolveAction(name: string, args: Record<string, unknown>): Promise<AiActionResolution>;
  };
  actionExecutor?: (input: {
    operation: AiActionOperation;
    targetId: string;
    actorId: string;
    actorRole: string;
    requestId?: string;
  }) => Promise<unknown>;
  confirmationStore?: Map<string, StoredConfirmation>;
  timeoutMs?: number;
  deadlineMs?: number;
  model?: string;
  apiKey?: string | null;
}

interface StoredConfirmation {
  operation: AiActionOperation;
  target: AiActionResolution['target'];
  args: Record<string, unknown>;
  actorId: string;
  createdAt: number;
  expiresAt: number;
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

const ASSISTANT_SYSTEM_INSTRUCTION = `
You are the PayMuster Super Admin assistant. You answer the administrator's questions and propose platform operations using ONLY the provided tools.

Rules:
- Answer the question directly and concisely, using the REAL data returned by the tools. Never invent numbers, names, or statuses.
- Call a read tool whenever the question needs live platform data (counts, lists, statuses, health, activity).
- For state-changing operations you may only PROPOSE the whitelisted operations exposed as action tools. Calling an action tool never executes anything — it produces a confirmation the administrator must explicitly approve.
- If the administrator asks for something destructive or outside your tools, say plainly that it is not supported and point to the existing Admin workflows. Never output SQL, shell commands, credentials, or personal data beyond what tools returned.
- Prefer numbers and concrete names from tool output over generic statements.
`.trim();

const operationalContextReader = async (request: AdminAiRequest): Promise<AdminAiOperationalContext> => {
  const globalScope = request.role === 'SUPER_ADMIN' && !request.orgId;
  // A sentinel string would break Postgres uuid-typed where clauses; a
  // non-global request without an org is rejected cleanly instead.
  if (!globalScope && !request.orgId) {
    throw new AppError(
      'AI_CONTEXT_ERROR',
      'AI analysis requires an organization scope.',
      400,
    );
  }
  const orgId = globalScope ? undefined : request.orgId ?? undefined;
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
        ...(record.detail && { detail: record.detail }),
        ...(record.errorCode && { errorCode: record.errorCode }),
      },
    },
  });
};

/** Default confirmed-action executor: the existing authorized service layer. */
const defaultActionExecutor: NonNullable<AiServiceDependencies['actionExecutor']> = async ({
  operation,
  targetId,
  actorId,
  actorRole,
  requestId,
}) => {
  switch (operation) {
    case 'GRANT_UNLIMITED':
      return subscriptionService.grantUnlimitedAccess(targetId, actorId, actorRole);
    case 'REVOKE_UNLIMITED':
      return subscriptionService.revokeUnlimitedAccess(targetId, actorId, actorRole);
    case 'SUSPEND_USER':
      return adminService.executeAction(targetId, actorId, 'SUSPEND', undefined, { requestId });
    case 'BLOCK_USER':
      return adminService.executeAction(targetId, actorId, 'BLOCK', undefined, { requestId });
    case 'UNSUSPEND_USER':
      return adminService.executeAction(targetId, actorId, 'UNSUSPEND', undefined, { requestId });
    case 'UNBLOCK_USER':
      return adminService.executeAction(targetId, actorId, 'UNBLOCK', undefined, { requestId });
    default:
      throw new AppError('AI_ACTION_FORBIDDEN', 'This operation is not supported by the AI assistant.', 400);
  }
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

/**
 * Maps the admin-assistant conversation onto Gemini `contents`. Model turns
 * replay the provider's original parts verbatim when available: Gemini 3.x
 * returns functionCall parts carrying a thoughtSignature and rejects the next
 * request (400 INVALID_ARGUMENT) if a replayed model turn omits it, so the
 * raw parts must round-trip through the conversation history.
 */
export function buildGeminiContents(messages: AdminAiChatMessage[]): unknown[] {
  return messages.map((message) => {
    if (message.role === 'user') {
      return { role: 'user' as const, parts: [{ text: message.text ?? '' }] };
    }
    if (message.role === 'model') {
      const rawParts = (message.parts ?? []).filter(
        (part) => part && typeof part === 'object' && 'functionCall' in (part as Record<string, unknown>),
      );
      if (rawParts.length > 0) {
        return { role: 'model' as const, parts: rawParts };
      }
      return {
        role: 'model' as const,
        parts: (message.functionCalls ?? []).map((call) => ({
          functionCall: { name: call.name, args: call.args },
        })),
      };
    }
    return {
      role: 'user' as const,
      parts: (message.functionResponses ?? []).map((response) => ({
        functionResponse: {
          name: response.name,
          response: response.response as Record<string, unknown>,
        },
      })),
    };
  });
}

/** Gemini chat provider with function calling for the admin assistant. */
class GeminiChatProvider implements AdminAiChatProvider {
  private readonly ai: GoogleGenAI;
  private readonly model: string;

  constructor(apiKey: string, model: string) {
    this.ai = new GoogleGenAI({ apiKey });
    this.model = model;
  }

  async chat(input: {
    systemInstruction: string;
    tools: AiToolDeclaration[];
    messages: AdminAiChatMessage[];
  }): Promise<{ text?: string | null; functionCalls?: AdminAiFunctionCall[]; parts?: unknown[] }> {
    const contents = buildGeminiContents(input.messages);

    const response = await this.ai.models.generateContent({
      model: this.model,
      // The contents mix concrete part shapes with the provider's verbatim
      // replay parts (thoughtSignature is not exposed in the SDK's Part type),
      // so the union is asserted through — mirrors the tools cast above.
      contents: contents as never[],
      config: {
        systemInstruction: input.systemInstruction,
        tools: [{ functionDeclarations: input.tools as never[] }],
        temperature: 0.2,
      },
    });

    const functionCalls = response.functionCalls?.map((call) => ({
      name: call.name ?? '',
      args: (call.args ?? {}) as Record<string, unknown>,
    }));
    // Preserve the model's raw parts (incl. thoughtSignature) for replay.
    const rawParts: unknown[] =
      (response as { candidates?: Array<{ content?: { parts?: unknown[] } }> })
        .candidates?.[0]?.content?.parts ?? [];
    return { text: response.text ?? null, functionCalls, parts: rawParts };
  }
}

export class AiService {
  private readonly provider?: AdminAiProvider;
  private readonly chatProvider?: AdminAiChatProvider;
  private readonly contextReader: (request: AdminAiRequest) => Promise<AdminAiOperationalContext>;
  private readonly auditWriter: NonNullable<AiServiceDependencies['auditWriter']>;
  private readonly toolRegistry: NonNullable<AiServiceDependencies['toolRegistry']>;
  private readonly actionExecutor: NonNullable<AiServiceDependencies['actionExecutor']>;
  private readonly confirmationStore: Map<string, StoredConfirmation>;
  private readonly timeoutMs: number;
  private readonly deadlineMs: number;
  private readonly model: string;
  private readonly apiKey?: string;

  constructor(dependencies: AiServiceDependencies = {}) {
    this.provider = dependencies.provider;
    this.chatProvider = dependencies.chatProvider;
    this.contextReader = dependencies.contextReader ?? operationalContextReader;
    this.auditWriter = dependencies.auditWriter ?? defaultAuditWriter;
    this.toolRegistry = dependencies.toolRegistry ?? adminAiToolRegistry;
    this.actionExecutor = dependencies.actionExecutor ?? defaultActionExecutor;
    this.confirmationStore = dependencies.confirmationStore ?? new Map();
    this.timeoutMs = dependencies.timeoutMs ?? config.geminiTimeoutMs;
    this.deadlineMs = dependencies.deadlineMs ?? config.aiOverallDeadlineMs;
    this.model = dependencies.model ?? config.geminiModel;
    this.apiKey = dependencies.apiKey === undefined
      ? config.geminiApiKey
      : dependencies.apiKey ?? undefined;
  }

  // -------------------------------------------------------------------------
  // Admin assistant (tool-calling). SUPER_ADMIN only — enforced here again as
  // defense in depth on top of the manage_system route gate.
  // -------------------------------------------------------------------------

  async processChat(request: AdminAiRequest): Promise<AdminAiChatResult> {
    const startedAt = Date.now();
    if (request.role !== 'SUPER_ADMIN') {
      throw new AppError(
        'AI_UNAUTHORIZED',
        'The AI assistant is available to Super Admins only.',
        403,
      );
    }

    // Confirmation path: the admin approved a previously proposed operation.
    if (request.confirmationToken) {
      return this.executeConfirmedAction(request, startedAt);
    }

    const provider = this.resolveChatProvider();
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

    const providerName = this.chatProvider ? 'injected' : PROVIDER_NAME;
    const messages: AdminAiChatMessage[] = [{ role: 'user', text: request.prompt }];
    const toolCalls: AdminAiChatResult['toolCalls'] = [];
    const entities: AiEntity[] = [];
    let metrics: Record<string, number> | null = null;
    let contextUsed: Record<string, number> | null = null;
    let finalMessage: string | null = null;
    let lastError: AppError | null = null;

    const deadline = startedAt + this.deadlineMs;

    try {
      for (let round = 0; round < MAX_TOOL_ROUNDS; round += 1) {
        const remaining = deadline - Date.now();
        if (remaining <= 0) {
          lastError = new AppError('AI_TIMEOUT', 'AI analysis timed out. Please try again.', 504);
          break;
        }

        let response: Awaited<ReturnType<AdminAiChatProvider['chat']>>;
        try {
          response = await this.withTimeout(
            provider.chat({
              systemInstruction: ASSISTANT_SYSTEM_INSTRUCTION,
              tools: AI_TOOL_DECLARATIONS,
              messages,
            }),
            Math.min(this.timeoutMs, remaining),
          );
        } catch (error) {
          lastError = this.classifyProviderError(error);
          break;
        }

        const calls = response.functionCalls ?? [];
        if (calls.length === 0) {
          finalMessage = typeof response.text === 'string' && response.text.trim().length > 0
            ? response.text.trim()
            : null;
          if (finalMessage) break;
          // Empty response with no calls: treat as invalid and stop the loop.
          lastError = new AppError('AI_INVALID_RESPONSE', 'The AI provider returned an empty response.', 502);
          break;
        }

        // Keep the provider's raw parts (incl. Gemini thoughtSignature) on the
        // model turn so the next round replays them verbatim — Gemini 3.x
        // rejects a model turn whose functionCall parts lack the signature.
        messages.push({
          role: 'model',
          functionCalls: calls,
          parts: response.parts,
        });

        // Execute every requested tool; an action tool short-circuits the loop
        // into a confirmation (never executes on proposal).
        let shortCircuit: { resolution: AiActionResolution; toolName: string } | null = null;
        const functionResponses: Array<{ name: string; response: unknown }> = [];

        for (const call of calls) {
          if (isActionTool(call.name)) {
            const resolution = await this.toolRegistry.resolveAction(call.name, call.args);
            shortCircuit = { resolution, toolName: call.name };
            functionResponses.push({
              name: call.name,
              response: {
                status: 'CONFIRMATION_REQUIRED',
                operation: resolution.operation,
                target: resolution.target,
                consequences: resolution.consequences,
              },
            });
            break;
          }
          if (!isReadTool(call.name)) {
            functionResponses.push({
              name: call.name,
              response: { status: 'ERROR', message: `Unknown tool "${call.name}".` },
            });
            continue;
          }
          try {
            const result = await this.toolRegistry.execute(call.name, call.args);
            toolCalls.push({ name: call.name, args: call.args, summary: result.summary });
            entities.push(...result.entities);
            if (call.name === 'platform_stats') {
              metrics = result.data as Record<string, number>;
              contextUsed = result.data as Record<string, number>;
            }
            functionResponses.push({
              name: call.name,
              response: { status: 'OK', summary: result.summary, data: result.data },
            });
          } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            functionResponses.push({
              name: call.name,
              response: { status: 'ERROR', message },
            });
          }
        }

        messages.push({ role: 'tool', functionResponses });

        if (shortCircuit) {
          return this.buildConfirmationResult(
            request,
            shortCircuit.resolution,
            { providerName, toolCalls, entities, metrics, contextUsed, startedAt },
          );
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('AI assistant loop failed', { error: message, requestId: request.requestId });
      lastError = this.classifyProviderError(error);
    }

    if (finalMessage) {
      recordProviderSuccess(PROVIDER_NAME);
      const result: AdminAiChatResult = {
        message: finalMessage,
        intent: 'ANSWER',
        provider: providerName,
        model: this.model,
        generatedAt: new Date().toISOString(),
        toolCalls,
        entities,
        metrics,
        contextUsed,
        degraded: false,
        durationMs: Date.now() - startedAt,
      };
      await this.writeAudit(request, {
        status: 'COMPLETED',
        provider: providerName,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: result.durationMs,
        detail: { intent: result.intent, toolCalls: toolCalls.map((t) => t.name) },
      });
      return result;
    }

    // Data-first degradation: the model could not finish composing an answer,
    // but real tool data was retrieved. Surface the data honestly instead of
    // failing the whole request — this is the fix for "AI analysis timed out"
    // hiding already-retrieved facts behind one slow provider call.
    if (toolCalls.length > 0) {
      const summary = toolCalls.map((t) => t.summary).join('\n');
      const result: AdminAiChatResult = {
        message:
          `The AI model could not compose a final answer (${
            lastError ? lastError.message : 'no final response'
          }), but this live data was retrieved from the platform:\n${summary}`,
        intent: 'DATA_FALLBACK',
        provider: providerName,
        model: this.model,
        generatedAt: new Date().toISOString(),
        toolCalls,
        entities,
        metrics,
        contextUsed,
        degraded: true,
        durationMs: Date.now() - startedAt,
      };
      await this.writeAudit(request, {
        status: 'COMPLETED',
        provider: providerName,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: result.durationMs,
        errorCode: lastError?.code,
        detail: { intent: result.intent, toolCalls: toolCalls.map((t) => t.name) },
      });
      return result;
    }

    // No data, no answer — fail honestly with the classified error.
    const appError = lastError ?? new AppError('AI_PROCESSING_ERROR', 'AI analysis could not be completed.', 502);
    await this.writeAudit(request, {
      status: appError.code === 'AI_TIMEOUT' ? 'TIMEOUT' : 'FAILED',
      provider: providerName,
      model: this.model,
      promptLength: request.prompt.length,
      durationMs: Date.now() - startedAt,
      errorCode: appError.code,
    });
    throw appError;
  }

  private async buildConfirmationResult(
    request: AdminAiRequest,
    resolution: AiActionResolution,
    collected: {
      providerName: string;
      toolCalls: AdminAiChatResult['toolCalls'];
      entities: AiEntity[];
      metrics: Record<string, number> | null;
      contextUsed: Record<string, number> | null;
      startedAt: number;
    },
  ): Promise<AdminAiChatResult> {
    // Purge expired confirmations (single-use tokens with a TTL).
    const now = Date.now();
    for (const [token, stored] of this.confirmationStore) {
      if (stored.expiresAt <= now) this.confirmationStore.delete(token);
    }

    const token = randomUUID();
    this.confirmationStore.set(token, {
      operation: resolution.operation,
      target: resolution.target,
      args: {},
      actorId: request.actorId,
      createdAt: now,
      expiresAt: now + CONFIRMATION_TTL_MS,
    });
    if (resolution.entity) addEntity(collected.entities, resolution.entity);

    const expiresAt = new Date(now + CONFIRMATION_TTL_MS).toISOString();
    const result: AdminAiChatResult = {
      message:
        `Confirmation required before anything changes. ${resolution.consequences}\n\n` +
        `Reply with this confirmation token to execute: ${token} (valid until ${expiresAt}). ` +
        'The operation will run through the audited admin service layer; nothing is executed until you confirm.',
      intent: 'CONFIRMATION_REQUIRED',
      provider: collected.providerName,
      model: this.model,
      generatedAt: new Date().toISOString(),
      toolCalls: collected.toolCalls,
      entities: collected.entities,
      metrics: collected.metrics,
      contextUsed: collected.contextUsed,
      confirmation: {
        operation: resolution.operation,
        target: resolution.target,
        currentState: resolution.currentState,
        consequences: resolution.consequences,
        expiresAt,
        token,
      },
      degraded: false,
      durationMs: Date.now() - collected.startedAt,
    };

    await this.writeAudit(request, {
      status: 'CONFIRMATION_REQUIRED',
      provider: collected.providerName,
      model: this.model,
      promptLength: request.prompt.length,
      durationMs: result.durationMs,
      detail: {
        operation: resolution.operation,
        targetId: resolution.target.id,
        targetPublicId: resolution.target.publicId ?? null,
      },
    });
    return result;
  }

  private async executeConfirmedAction(request: AdminAiRequest, startedAt: number): Promise<AdminAiChatResult> {
    const stored = this.confirmationStore.get(request.confirmationToken as string);
    if (!stored || stored.expiresAt <= Date.now()) {
      await this.writeAudit(request, {
        status: 'ACTION_REJECTED',
        provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: 'AI_CONFIRMATION_INVALID',
      });
      throw new AppError(
        'AI_CONFIRMATION_INVALID',
        'This confirmation is invalid, expired, or already used. Ask again and confirm the new proposal.',
        400,
      );
    }
    // Tokens are single-use and bound to the actor who requested them.
    this.confirmationStore.delete(request.confirmationToken as string);
    if (stored.actorId !== request.actorId) {
      await this.writeAudit(request, {
        status: 'ACTION_REJECTED',
        provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: 'AI_CONFIRMATION_ACTOR_MISMATCH',
      });
      throw new AppError(
        'AI_CONFIRMATION_ACTOR_MISMATCH',
        'This confirmation belongs to a different administrator.',
        403,
      );
    }
    // Server-side SUPER_ADMIN re-enforcement (never trusts the token alone).
    if (request.role !== 'SUPER_ADMIN') {
      await this.writeAudit(request, {
        status: 'ACTION_REJECTED',
        provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: 'AI_UNAUTHORIZED',
      });
      throw new AppError('AI_UNAUTHORIZED', 'Only Super Admins can execute operations through the AI assistant.', 403);
    }

    let executionResult: unknown;
    try {
      executionResult = await this.actionExecutor({
        operation: stored.operation,
        targetId: stored.target.id,
        actorId: request.actorId,
        actorRole: 'SUPER_ADMIN',
        requestId: request.requestId,
      });
    } catch (error) {
      const appError = error instanceof AppError ? error : new AppError('AI_ACTION_FAILED', 'The operation could not be executed.', 502);
      await this.writeAudit(request, {
        status: 'ACTION_REJECTED',
        provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
        model: this.model,
        promptLength: request.prompt.length,
        durationMs: Date.now() - startedAt,
        errorCode: appError.code,
        detail: { operation: stored.operation, targetId: stored.target.id },
      });
      throw appError;
    }

    const subscriptionResult = executionResult as { id?: string; unlimitedAccess?: boolean; status?: string } | undefined;
    const result: AdminAiChatResult = {
      message:
        `Executed ${stored.operation} on ${stored.target.name ?? stored.target.id}` +
        (subscriptionResult?.unlimitedAccess !== undefined
          ? ` — unlimited access is now ${subscriptionResult.unlimitedAccess ? 'GRANTED' : 'REVOKED'}.`
          : '.') +
        ' The change is audited and the affected users/owners have been notified through the standard notification flow.',
      intent: 'ACTION_EXECUTED',
      provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
      model: this.model,
      generatedAt: new Date().toISOString(),
      toolCalls: [],
      entities: stored.target.type === 'org'
        ? [{ type: 'org', id: stored.target.id, publicId: stored.target.publicId, name: stored.target.name, subtitle: null, route: `/admin/subscriptions/${stored.target.id}` }]
        : [{ type: 'user', id: stored.target.id, publicId: stored.target.publicId, name: stored.target.name, subtitle: stored.target.subtitle ?? null, route: `/admin/users/${stored.target.id}` }],
      metrics: null,
      contextUsed: null,
      executedAction: {
        operation: stored.operation,
        targetId: stored.target.id,
        targetName: stored.target.name ?? null,
        status: 'EXECUTED',
        result: executionResult,
      },
      degraded: false,
      durationMs: Date.now() - startedAt,
    };

    await this.writeAudit(request, {
      status: 'ACTION_EXECUTED',
      provider: this.chatProvider ? 'injected' : PROVIDER_NAME,
      model: this.model,
      promptLength: request.prompt.length,
      durationMs: result.durationMs,
      detail: {
        operation: stored.operation,
        targetId: stored.target.id,
        targetPublicId: stored.target.publicId ?? null,
      },
    });
    return result;
  }

  // -------------------------------------------------------------------------
  // Foundation analysis (member scope, no tools) — unchanged behavior.
  // -------------------------------------------------------------------------

  async processFoundation(
    operation: 'ANALYZE' | 'SUMMARY' | 'INSIGHTS' | 'QUERY',
    request: AdminAiRequest,
  ) {
    const { message, provider, model, generatedAt, scope } = await this.runAnalysisPipeline({
      ...request,
      prompt: `[${operation}] ${request.prompt}`,
    });
    return {
      analysis: message,
      recommendation: null,
      proposal: null,
      confidence: null,
      metadata: {
        operation,
        provider,
        model,
        generatedAt,
        scope,
        mutationsAllowed: false,
      },
    };
  }

  private async runAnalysisPipeline(request: AdminAiRequest) {
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
    if (!this.provider) recordProviderSuccess(PROVIDER_NAME);

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

  // -------------------------------------------------------------------------

  private resolveChatProvider(): AdminAiChatProvider | undefined {
    if (this.chatProvider) return this.chatProvider;
    if (this.apiKey) return new GeminiChatProvider(this.apiKey, this.model);
    return undefined;
  }

  private async withTimeout<T>(promise: Promise<T>, timeoutMs = this.timeoutMs): Promise<T> {
    let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new AppError(
          'AI_TIMEOUT',
          'AI analysis timed out. Please try again.',
          504,
          { retryAfterSeconds: 5 },
        ));
      }, timeoutMs);
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
    // Gemini free-tier quotas (e.g. 20 requests/min) surface as 429
    // RESOURCE_EXHAUSTED with a retry window in the message. Report it as an
    // explicit rate-limit with a retry hint instead of a generic failure so
    // the admin knows the provider is configured and working — just throttled.
    if (/\b429\b|RESOURCE_EXHAUSTED|quota/i.test(message)) {
      return new AppError(
        'AI_RATE_LIMITED',
        'The AI provider rate limit is exhausted. Please retry in about a minute.',
        503,
        { retryAfterSeconds: 60 },
      );
    }
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

function addEntity(entities: AiEntity[], entity: AiEntity) {
  if (!entities.some((e) => e.type === entity.type && e.id === entity.id)) {
    entities.push(entity);
  }
}

export const aiService = new AiService();
