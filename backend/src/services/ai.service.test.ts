import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/app-error.js';
import {
    adminAiChatSchema,
    type AdminAiProviderResponse,
} from '../schemas/admin-ai.schema.js';
import {
    AiService,
    buildGeminiContents,
    type AdminAiOperationalContext,
    type AdminAiProvider,
    type AdminAiChatProvider,
    type AdminAiChatMessage,
    type AiActionResolution,
    type AiToolResult,
} from './ai.service.js';

const actorId = '11111111-1111-4111-8111-111111111111';
const otherActorId = '99999999-9999-4999-8999-999999999999';
const orgId = '22222222-2222-4222-8222-222222222222';
const context: AdminAiOperationalContext = {
    users: 12,
    companies: 3,
    sites: 7,
    attendance: 42,
    payroll: 5,
    pendingOwnerRequests: 2,
    blockedUsers: 1,
};

function assertAppError(
    error: unknown,
    expected: { code: string; status: number },
): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, expected.code);
    assert.equal(error.status, expected.status);
    return true;
}

function request() {
    return {
        prompt: 'Review the current attendance and payroll posture.',
        actorId,
        orgId,
        requestId: 'request-ai-1',
        ipAddress: '203.0.113.10',
        userAgent: 'test-agent',
    };
}

function adminRequest(overrides: Record<string, unknown> = {}) {
    return {
        prompt: 'How many users are on the platform?',
        actorId,
        role: 'SUPER_ADMIN',
        orgId: null,
        requestId: 'request-ai-admin-1',
        ...overrides,
    };
}

function providerStub(
    generateAnalysis: AdminAiProvider['generateAnalysis'],
): AdminAiProvider {
    return { generateAnalysis };
}

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

test('Admin AI request schema rejects client-controlled context and unknown fields', () => {
    const result = adminAiChatSchema.safeParse({
        prompt: '  analyze attendance  ',
        context: { users: 999 },
    });

    assert.equal(result.success, false);
    if (!result.success) {
        assert.ok(result.error.issues.some((issue) => issue.code === 'unrecognized_keys'));
    }

    assert.deepEqual(adminAiChatSchema.parse({ prompt: '  analyze attendance  ' }), {
        prompt: 'analyze attendance',
    });
    assert.deepEqual(
        adminAiChatSchema.parse({ prompt: 'confirm', confirmationToken: '123e4567-e89b-42d3-a456-426614174000' }),
        { prompt: 'confirm', confirmationToken: '123e4567-e89b-42d3-a456-426614174000' },
    );
    assert.equal(adminAiChatSchema.safeParse({ prompt: 'x', confirmationToken: 'not-a-uuid' }).success, false);
});

// ---------------------------------------------------------------------------
// Foundation analysis pipeline (member scope, no tools) — unchanged semantics
// ---------------------------------------------------------------------------

test('Foundation AI returns validated analysis only and supplies backend-owned context', async () => {
    let providerInput: unknown;
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(async (input) => {
            providerInput = input;
            return { message: 'Attendance is available for review.' } satisfies AdminAiProviderResponse;
        }),
        contextReader: async () => context,
        auditWriter: async (input) => {
            auditInput = input;
        },
        timeoutMs: 100,
        model: 'test-model',
    });

    const result = await service.processFoundation('ANALYZE', request());

    assert.deepEqual(providerInput, {
        prompt: '[ANALYZE] Review the current attendance and payroll posture.',
        context,
    });
    assert.equal(result.analysis, 'Attendance is available for review.');
    assert.equal(result.metadata.provider, 'injected');
    assert.equal(result.metadata.model, 'test-model');
    assert.deepEqual(result.metadata.scope, context);
    assert.equal(result.metadata.mutationsAllowed, false);
    assert.equal(auditInput.actorId, actorId);
    assert.equal(auditInput.record.status, 'COMPLETED');
    assert.equal('prompt' in auditInput.record, false);
});

test('Admin AI reports unavailable provider without reading operational data', async () => {
    let contextRead = false;
    let auditInput: any;
    const service = new AiService({
        apiKey: null,
        contextReader: async () => {
            contextRead = true;
            return context;
        },
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processFoundation('ANALYZE', request()),
        (error) => assertAppError(error, { code: 'AI_UNAVAILABLE', status: 503 }),
    );
    assert.equal(contextRead, false);
    assert.equal(auditInput.record.status, 'UNAVAILABLE');
    assert.equal(auditInput.record.errorCode, 'AI_UNAVAILABLE');
    assert.equal(auditInput.record.context, undefined);
});

test('Admin AI converts a slow provider into a bounded timeout and audits it', async () => {
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(() => new Promise(() => undefined)),
        contextReader: async () => context,
        auditWriter: async (input) => {
            auditInput = input;
        },
        timeoutMs: 5,
    });

    await assert.rejects(
        service.processFoundation('ANALYZE', request()),
        (error) => assertAppError(error, { code: 'AI_TIMEOUT', status: 504 }),
    );
    assert.equal(auditInput.record.status, 'TIMEOUT');
    assert.equal(auditInput.record.errorCode, 'AI_TIMEOUT');
});

test('Admin AI rejects malformed provider output and audits the invalid response', async () => {
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(async () => ({
            message: 'Valid analysis',
            proposal: { action: 'DELETE_USER' },
        })),
        contextReader: async () => context,
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processFoundation('ANALYZE', request()),
        (error) => assertAppError(error, { code: 'AI_INVALID_RESPONSE', status: 502 }),
    );
    assert.equal(auditInput.record.status, 'INVALID_RESPONSE');
    assert.equal(auditInput.record.errorCode, 'AI_INVALID_RESPONSE');
});

test('Admin AI audits operational context failures without calling the provider', async () => {
    let providerCalled = false;
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(async () => {
            providerCalled = true;
            return { message: 'Analysis' };
        }),
        contextReader: async () => {
            throw new Error('aggregate read failed');
        },
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processFoundation('ANALYZE', request()),
        (error) => assertAppError(error, { code: 'AI_CONTEXT_ERROR', status: 500 }),
    );
    assert.equal(providerCalled, false);
    assert.equal(auditInput.record.status, 'FAILED');
    assert.equal(auditInput.record.errorCode, 'AI_CONTEXT_ERROR');
    assert.equal(auditInput.record.context, undefined);
});

test('Admin AI fails closed when analysis audit persistence fails', async () => {
    const service = new AiService({
        provider: providerStub(async () => ({ message: 'Analysis' })),
        contextReader: async () => context,
        auditWriter: async () => {
            throw new Error('audit storage unavailable');
        },
    });

    await assert.rejects(
        service.processFoundation('ANALYZE', request()),
        (error) => assertAppError(error, { code: 'AI_AUDIT_ERROR', status: 500 }),
    );
});

// ---------------------------------------------------------------------------
// Admin assistant (tool-calling) — SUPER_ADMIN only
// ---------------------------------------------------------------------------

type ChatScriptTurn = Awaited<ReturnType<AdminAiChatProvider['chat']>>;

function chatProviderScript(scripts: ChatScriptTurn[]): AdminAiChatProvider & { calls: unknown[] } {
    const calls: unknown[] = [];
    let index = 0;
    return {
        calls,
        async chat(input) {
            calls.push(input);
            const script = scripts[Math.min(index, scripts.length - 1)];
            index += 1;
            return script;
        },
    };
}

const statsResult: AiToolResult = {
    tool: 'platform_stats',
    summary: '12 users, 3 companies, 2 pending owner requests.',
    data: { users: 12, companies: 3, organizations: 3, sites: 7, pendingOwnerRequests: 2 },
    entities: [],
};

function toolRegistryStub(overrides: Partial<{
    execute: (name: string, args: Record<string, unknown>) => Promise<AiToolResult>;
    resolveAction: (name: string, args: Record<string, unknown>) => Promise<AiActionResolution>;
}> = {}) {
    const executed: Array<{ name: string; args: Record<string, unknown> }> = [];
    const resolved: Array<{ name: string; args: Record<string, unknown> }> = [];
    return {
        executed,
        resolved,
        async execute(name: string, args: Record<string, unknown>) {
            executed.push({ name, args });
            if (overrides.execute) return overrides.execute(name, args);
            return statsResult;
        },
        async resolveAction(name: string, args: Record<string, unknown>) {
            resolved.push({ name, args });
            if (overrides.resolveAction) return overrides.resolveAction(name, args);
            throw new AppError('AI_TOOL_UNAVAILABLE', 'not an action', 400);
        },
    };
}

// ---------------------------------------------------------------------------
// thoughtSignature replay (Gemini 3.x requirement)
//
// Gemini 3.x returns functionCall parts carrying a thoughtSignature and rejects
// the next request with 400 INVALID_ARGUMENT ("Function call is missing a
// thought_signature in functionCall parts") if a replayed model turn omits it.
// Regression: the loop must round-trip the provider's raw parts.
// ---------------------------------------------------------------------------

test('chat loop replays the provider raw parts (thoughtSignature) on model turns', async () => {
    const signedParts = [
        {
            functionCall: { name: 'platform_stats', args: {} },
            thoughtSignature: 'c2lnbmF0dXJlLWJ5dGVz',
        },
    ];
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'platform_stats', args: {} }], parts: signedParts },
        { text: 'There are 12 users.' },
    ]);
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: toolRegistryStub(),
        auditWriter: async () => undefined,
    });

    const result = await service.processChat(adminRequest());

    assert.equal(result.intent, 'ANSWER');
    assert.equal(provider.calls.length, 2);
    const secondCallMessages = (provider.calls[1] as { messages: AdminAiChatMessage[] }).messages;
    const modelTurn = secondCallMessages.find((message) => message.role === 'model');
    assert.ok(modelTurn);
    assert.deepEqual(modelTurn.parts, signedParts);
});

test('buildGeminiContents replays signed parts verbatim and synthesizes unsigned turns', () => {
    const signedPart = {
        functionCall: { name: 'platform_stats', args: { detailed: false } },
        thoughtSignature: 'c2lnbmF0dXJlLWJ5dGVz',
    };
    const contents = buildGeminiContents([
        { role: 'user', text: 'How many users?' },
        { role: 'model', parts: [signedPart, { text: 'thinking' }] },
        { role: 'tool', functionResponses: [{ name: 'platform_stats', response: { status: 'OK' } }] },
        // Unsigned model turn (e.g. replayed from a scripted provider) still
        // synthesizes plain functionCall parts.
        { role: 'model', functionCalls: [{ name: 'list_users', args: { limit: 5 } }] },
    ] satisfies AdminAiChatMessage[]);

    assert.deepEqual(contents, [
        { role: 'user', parts: [{ text: 'How many users?' }] },
        // Only the functionCall part is replayed; stray text parts dropped.
        { role: 'model', parts: [signedPart] },
        {
            role: 'user',
            parts: [{ functionResponse: { name: 'platform_stats', response: { status: 'OK' } } }],
        },
        {
            role: 'model',
            parts: [{ functionCall: { name: 'list_users', args: { limit: 5 } } }],
        },
    ]);
});

test('Admin assistant is SUPER_ADMIN only — other roles are rejected before any provider or tool call', async () => {
    const provider = chatProviderScript([{ text: 'should not be called' }]);
    const registry = toolRegistryStub();
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        auditWriter: async () => undefined,
    });

    await assert.rejects(
        service.processChat(adminRequest({ role: 'OWNER' })),
        (error) => assertAppError(error, { code: 'AI_UNAUTHORIZED', status: 403 }),
    );
    assert.equal(provider.calls.length, 0);
    assert.equal(registry.executed.length, 0);
});

test('Admin assistant answers conversational data questions with real tool data', async () => {
    let auditInput: any;
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'platform_stats', args: {} }] },
        { text: 'There are 12 users on the platform, 3 companies and 2 pending owner requests.' },
    ]);
    const registry = toolRegistryStub();
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        auditWriter: async (input) => {
            auditInput = input;
        },
        model: 'test-model',
    });

    const result = await service.processChat(adminRequest());

    assert.equal(result.intent, 'ANSWER');
    assert.equal(result.message, 'There are 12 users on the platform, 3 companies and 2 pending owner requests.');
    assert.deepEqual(result.toolCalls, [{ name: 'platform_stats', args: {}, summary: statsResult.summary }]);
    assert.deepEqual(result.metrics, statsResult.data);
    assert.equal(result.degraded, false);
    assert.equal(result.provider, 'injected');
    assert.equal(result.model, 'test-model');
    // The tool result was fed back to the model as a function response.
    const toolMessage = (provider.calls[1] as { messages: Array<{ role: string; functionResponses?: unknown[] }> }).messages.find((m) => m.role === 'tool');
    assert.ok(toolMessage?.functionResponses?.[0]);
    assert.equal(registry.executed.length, 1);
    assert.equal(auditInput.record.status, 'COMPLETED');
    assert.deepEqual(auditInput.record.detail.toolCalls, ['platform_stats']);
    assert.equal('prompt' in auditInput.record, false);
});

test('Admin assistant reports unavailable provider (no API key, no injection)', async () => {
    let auditInput: any;
    const service = new AiService({
        apiKey: null,
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processChat(adminRequest()),
        (error) => assertAppError(error, { code: 'AI_UNAVAILABLE', status: 503 }),
    );
    assert.equal(auditInput.record.status, 'UNAVAILABLE');
});

test('Timeout during composition still returns retrieved data honestly (data-first degradation)', async () => {
    let auditInput: any;
    // First call requests the tool; the second (composition) call hangs past
    // the per-call timeout. The old pipeline returned a bare 504 that hid the
    // already-retrieved data — the fix surfaces the data with a degraded flag.
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'platform_stats', args: {} }] },
        new Promise(() => undefined) as never,
    ]);
    const registry = toolRegistryStub();
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        auditWriter: async (input) => {
            auditInput = input;
        },
        timeoutMs: 10,
    });

    const result = await service.processChat(adminRequest());

    assert.equal(result.intent, 'DATA_FALLBACK');
    assert.equal(result.degraded, true);
    assert.ok(result.message.includes('12 users'));
    assert.ok(result.message.includes('could not compose'));
    assert.deepEqual(result.toolCalls, [{ name: 'platform_stats', args: {}, summary: statsResult.summary }]);
    assert.equal(auditInput.record.status, 'COMPLETED');
    assert.equal(auditInput.record.errorCode, 'AI_TIMEOUT');
});

test('Destructive operation proposes a confirmation and executes NOTHING', async () => {
    let auditInput: any;
    let executedOperation: string | null = null;
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'grant_unlimited_access', args: { orgRef: 'Acme Construction' } }] },
        { text: 'unreachable' },
    ]);
    const resolution: AiActionResolution = {
        operation: 'GRANT_UNLIMITED',
        target: { type: 'org', id: orgId, publicId: 'PM-CMP-000001', name: 'Acme Construction', subtitle: null },
        currentState: { subscription: null },
        consequences: 'Grant unlimited access to Acme Construction: the organization bypasses all plan limits immediately.',
        entity: { type: 'org', id: orgId, publicId: 'PM-CMP-000001', name: 'Acme Construction', subtitle: null, route: `/admin/subscriptions/${orgId}` },
    };
    const registry = toolRegistryStub({ resolveAction: async () => resolution });
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        actionExecutor: async ({ operation }) => {
            executedOperation = operation;
            return { id: 'sub-1', unlimitedAccess: true };
        },
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    const result = await service.processChat(adminRequest({ prompt: 'Grant unlimited access to Acme Construction' }));

    assert.equal(result.intent, 'CONFIRMATION_REQUIRED');
    assert.equal(result.confirmation?.operation, 'GRANT_UNLIMITED');
    assert.equal(result.confirmation?.target.name, 'Acme Construction');
    assert.ok(result.confirmation?.token);
    assert.ok(result.message.includes('Confirmation required'));
    assert.equal(executedOperation, null, 'no operation may execute on proposal');
    assert.deepEqual(registry.resolved, [{ name: 'grant_unlimited_access', args: { orgRef: 'Acme Construction' } }]);
    assert.equal(auditInput.record.status, 'CONFIRMATION_REQUIRED');
    assert.equal(auditInput.record.detail.operation, 'GRANT_UNLIMITED');
});

test('Confirmed operation executes through the authorized service layer exactly once', async () => {
    const confirmations: Array<{ operation: string; targetId: string; actorRole: string }> = [];
    let auditInput: any;
    const provider = chatProviderScript([{ text: 'done' }]);
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: toolRegistryStub(),
        actionExecutor: async ({ operation, targetId, actorRole }) => {
            confirmations.push({ operation, targetId, actorRole });
            return { id: 'sub-1', unlimitedAccess: true };
        },
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    // Stage a pending confirmation the way the proposal flow created it.
    const store = (service as unknown as { confirmationStore: Map<string, unknown> }).confirmationStore;
    const token = '123e4567-e89b-42d3-a456-426614174000';
    store.set(token, {
        operation: 'GRANT_UNLIMITED',
        target: { type: 'org', id: orgId, publicId: 'PM-CMP-000001', name: 'Acme Construction', subtitle: null },
        args: {},
        actorId,
        createdAt: Date.now(),
        expiresAt: Date.now() + 60_000,
    });

    const result = await service.processChat(adminRequest({
        prompt: 'Confirmed — proceed',
        confirmationToken: token,
    }));

    assert.equal(result.intent, 'ACTION_EXECUTED');
    assert.equal(result.executedAction?.operation, 'GRANT_UNLIMITED');
    assert.equal(result.executedAction?.targetId, orgId);
    assert.deepEqual(confirmations, [{ operation: 'GRANT_UNLIMITED', targetId: orgId, actorRole: 'SUPER_ADMIN' }]);
    assert.ok(result.message.includes('unlimited access is now GRANTED'));
    assert.equal(auditInput.record.status, 'ACTION_EXECUTED');

    // Single-use: the same token cannot execute twice.
    await assert.rejects(
        service.processChat(adminRequest({ prompt: 'again', confirmationToken: token })),
        (error) => assertAppError(error, { code: 'AI_CONFIRMATION_INVALID', status: 400 }),
    );
    assert.equal(confirmations.length, 1);
});

test('Confirmation tokens are bound to the requesting administrator', async () => {
    const service = new AiService({
        chatProvider: chatProviderScript([{ text: 'done' }]),
        toolRegistry: toolRegistryStub(),
        actionExecutor: async () => ({ ok: true }),
        auditWriter: async () => undefined,
    });
    const store = (service as unknown as { confirmationStore: Map<string, unknown> }).confirmationStore;
    const token = '123e4567-e89b-42d3-a456-426614174001';
    store.set(token, {
        operation: 'SUSPEND_USER',
        target: { type: 'user', id: 'user-1', publicId: 'PM-USR-000001', name: 'John Doe', subtitle: 'john@example.com' },
        args: {},
        actorId: otherActorId,
        createdAt: Date.now(),
        expiresAt: Date.now() + 60_000,
    });

    await assert.rejects(
        service.processChat(adminRequest({ prompt: 'confirmed', confirmationToken: token })),
        (error) => assertAppError(error, { code: 'AI_CONFIRMATION_ACTOR_MISMATCH', status: 403 }),
    );
});

test('Expired confirmations are rejected', async () => {
    const service = new AiService({
        chatProvider: chatProviderScript([{ text: 'done' }]),
        toolRegistry: toolRegistryStub(),
        actionExecutor: async () => ({ ok: true }),
        auditWriter: async () => undefined,
    });
    const store = (service as unknown as { confirmationStore: Map<string, unknown> }).confirmationStore;
    const token = '123e4567-e89b-42d3-a456-426614174002';
    store.set(token, {
        operation: 'SUSPEND_USER',
        target: { type: 'user', id: 'user-1', publicId: null, name: null, subtitle: null },
        args: {},
        actorId,
        createdAt: Date.now() - 60_000,
        expiresAt: Date.now() - 1,
    });

    await assert.rejects(
        service.processChat(adminRequest({ prompt: 'confirmed', confirmationToken: token })),
        (error) => assertAppError(error, { code: 'AI_CONFIRMATION_INVALID', status: 400 }),
    );
});

test('Execution failure is audited as ACTION_REJECTED and surfaced', async () => {
    let auditInput: any;
    const service = new AiService({
        chatProvider: chatProviderScript([{ text: 'done' }]),
        toolRegistry: toolRegistryStub(),
        actionExecutor: async () => {
            throw new AppError('SUBSCRIPTION_NOT_FOUND', 'No active subscription found.', 404);
        },
        auditWriter: async (input) => {
            auditInput = input;
        },
    });
    const store = (service as unknown as { confirmationStore: Map<string, unknown> }).confirmationStore;
    const token = '123e4567-e89b-42d3-a456-426614174003';
    store.set(token, {
        operation: 'REVOKE_UNLIMITED',
        target: { type: 'org', id: orgId, publicId: null, name: 'Acme', subtitle: null },
        args: {},
        actorId,
        createdAt: Date.now(),
        expiresAt: Date.now() + 60_000,
    });

    await assert.rejects(
        service.processChat(adminRequest({ prompt: 'confirmed', confirmationToken: token })),
        (error) => assertAppError(error, { code: 'SUBSCRIPTION_NOT_FOUND', status: 404 }),
    );
    assert.equal(auditInput.record.status, 'ACTION_REJECTED');
    assert.equal(auditInput.record.errorCode, 'SUBSCRIPTION_NOT_FOUND');
});

test('Unknown tool names from the model are reported back as errors, never executed', async () => {
    const registry = toolRegistryStub();
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'run_sql', args: { query: 'DROP TABLE users' } }] },
        { text: 'That capability does not exist.' },
    ]);
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        auditWriter: async () => undefined,
    });

    const result = await service.processChat(adminRequest({ prompt: 'Drop every table' }));

    assert.equal(result.intent, 'ANSWER');
    assert.equal(registry.executed.length, 0);
    const toolMessage = (provider.calls[1] as { messages: Array<{ role: string; functionResponses?: Array<{ name: string; response: any }> }> }).messages.find((m) => m.role === 'tool');
    assert.equal(toolMessage?.functionResponses?.[0].name, 'run_sql');
    assert.equal(toolMessage?.functionResponses?.[0].response.status, 'ERROR');
});

test('Read-tool failures are surfaced to the model without aborting the request', async () => {
    const provider = chatProviderScript([
        { functionCalls: [{ name: 'list_users', args: {} }, { name: 'platform_stats', args: {} }] },
        { text: 'Stats retrieved; the user list query failed.' },
    ]);
    const registry = toolRegistryStub({
        execute: async (name) => {
            if (name === 'list_users') throw new Error('db read failed');
            return statsResult;
        },
    });
    const service = new AiService({
        chatProvider: provider,
        toolRegistry: registry,
        auditWriter: async () => undefined,
    });

    const result = await service.processChat(adminRequest());

    assert.equal(result.intent, 'ANSWER');
    assert.equal(result.toolCalls.length, 1);
    assert.equal(result.toolCalls[0].name, 'platform_stats');
});

test('Deadline exhaustion before any tool data fails honestly with a timeout', async () => {
    let auditInput: any;
    const service = new AiService({
        chatProvider: chatProviderScript([new Promise(() => undefined) as never]),
        toolRegistry: toolRegistryStub(),
        auditWriter: async (input) => {
            auditInput = input;
        },
        timeoutMs: 5,
        deadlineMs: 5,
    });

    await assert.rejects(
        service.processChat(adminRequest()),
        (error) => assertAppError(error, { code: 'AI_TIMEOUT', status: 504 }),
    );
    assert.equal(auditInput.record.status, 'TIMEOUT');
    assert.equal(auditInput.record.errorCode, 'AI_TIMEOUT');
});

test('Provider quota exhaustion (429) is surfaced as an explicit rate limit, not a processing error', async () => {
    let auditInput: any;
    const service = new AiService({
        chatProvider: {
            async chat() {
                throw new Error(
                    '{"error":{"code":429,"message":"You exceeded your current quota... RESOURCE_EXHAUSTED"}}',
                );
            },
        },
        toolRegistry: toolRegistryStub(),
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    const error: AppError = await service.processChat(adminRequest()).then(
        () => {
            throw new Error('expected a rejection');
        },
        (e) => e,
    );
    assertAppError(error, { code: 'AI_RATE_LIMITED', status: 503 });
    assert.equal(error.retryAfterSeconds, 60);
    assert.equal(auditInput.record.status, 'FAILED');
    assert.equal(auditInput.record.errorCode, 'AI_RATE_LIMITED');
});
