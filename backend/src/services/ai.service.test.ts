import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/app-error.js';
import {
    adminAiChatSchema,
    type AdminAiProviderResponse,
} from '../schemas/admin-ai.schema.js';
import {
    AiService,
    type AdminAiOperationalContext,
    type AdminAiProvider,
} from './ai.service.js';

const actorId = '11111111-1111-4111-8111-111111111111';
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
        orgId: '22222222-2222-4222-8222-222222222222',
        requestId: 'request-ai-1',
        ipAddress: '203.0.113.10',
        userAgent: 'test-agent',
    };
}

function providerStub(
    generateAnalysis: AdminAiProvider['generateAnalysis'],
): AdminAiProvider {
    return { generateAnalysis };
}

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
});

test('Admin AI returns validated analysis only and supplies backend-owned context', async () => {
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

    const result = await service.processChat(request());

    assert.deepEqual(providerInput, {
        prompt: request().prompt,
        context,
    });
    assert.equal(result.message, 'Attendance is available for review.');
    assert.equal(result.provider, 'injected');
    assert.equal(result.model, 'test-model');
    assert.deepEqual(result.scope, context);
    assert.equal('proposal' in result, false);
    assert.equal(auditInput.actorId, actorId);
    assert.equal(auditInput.record.status, 'COMPLETED');
    assert.deepEqual(auditInput.record.context, context);
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
        service.processChat(request()),
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
        service.processChat(request()),
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
        service.processChat(request()),
        (error) => assertAppError(error, { code: 'AI_INVALID_RESPONSE', status: 502 }),
    );
    assert.equal(auditInput.record.status, 'INVALID_RESPONSE');
    assert.equal(auditInput.record.errorCode, 'AI_INVALID_RESPONSE');
});

test('Admin AI classifies malformed provider JSON as an invalid response', async () => {
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(async () => '{"message":'),
        contextReader: async () => context,
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processChat(request()),
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
        service.processChat(request()),
        (error) => assertAppError(error, { code: 'AI_CONTEXT_ERROR', status: 500 }),
    );
    assert.equal(providerCalled, false);
    assert.equal(auditInput.record.status, 'FAILED');
    assert.equal(auditInput.record.errorCode, 'AI_CONTEXT_ERROR');
    assert.equal(auditInput.record.context, undefined);
});

test('Admin AI maps provider failures to a safe processing error and audits the failure', async () => {
    let auditInput: any;
    const service = new AiService({
        provider: providerStub(async () => {
            throw new Error('provider unavailable');
        }),
        contextReader: async () => context,
        auditWriter: async (input) => {
            auditInput = input;
        },
    });

    await assert.rejects(
        service.processChat(request()),
        (error) => assertAppError(error, { code: 'AI_PROCESSING_ERROR', status: 502 }),
    );
    assert.equal(auditInput.record.status, 'FAILED');
    assert.equal(auditInput.record.errorCode, 'AI_PROCESSING_ERROR');
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
        service.processChat(request()),
        (error) => assertAppError(error, { code: 'AI_AUDIT_ERROR', status: 500 }),
    );
});
