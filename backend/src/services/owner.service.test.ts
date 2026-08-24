import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { OwnerService } from './owner.service.js';

const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const sequenceDelegate = prisma.publicIdSequence as unknown as {
    upsert: typeof prisma.publicIdSequence.upsert;
};
const originalTransaction = mutablePrisma.$transaction;
const originalSequenceUpsert = sequenceDelegate.upsert;

const applicantId = '11111111-1111-4111-8111-111111111111';
const reviewerId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const organizationId = '44444444-4444-4444-8444-444444444444';

function assertAppError(error: unknown, expected: { code: string; status: number }): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, expected.code);
    assert.equal(error.status, expected.status);
    return true;
}

function useDeterministicPublicIds(): void {
    let counter = 0;
    sequenceDelegate.upsert = (async () => ({ counter: ++counter })) as unknown as typeof prisma.publicIdSequence.upsert;
}

afterEach(() => {
    mutablePrisma.$transaction = originalTransaction;
    sequenceDelegate.upsert = originalSequenceUpsert;
});

test('owner submission serializes by applicant and commits request and audit atomically', async () => {
    useDeterministicPublicIds();
    const calls: Array<{ operation: string; args?: unknown }> = [];
    const transactionClient = {
        $executeRaw: async (...args: unknown[]) => {
            calls.push({ operation: '$executeRaw', args });
            return 1;
        },
        user: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'user.findFirst', args });
                return { id: applicantId, orgId: null, role: 'STAFF' };
            },
        },
        ownerRequest: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'ownerRequest.findFirst', args });
                return null;
            },
            create: async (args: unknown) => {
                calls.push({ operation: 'ownerRequest.create', args });
                return { id: requestId, status: 'PENDING' };
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    let transactionOptions: unknown;
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
        options: unknown,
    ) => {
        transactionOptions = options;
        return callback(transactionClient);
    }) as unknown as typeof prisma.$transaction;

    const result = await new OwnerService().requestOwnership(
        applicantId,
        'Acme Construction',
        '29ABCDE1234F1Z5',
        'Bengaluru',
        'https://evidence.example/registration',
        'https://evidence.example/identity',
    ) as { id: string };

    assert.equal(result.id, requestId);
    assert.deepEqual(transactionOptions, { isolationLevel: 'Serializable' });
    assert.deepEqual(calls.map((call) => call.operation), [
        '$executeRaw',
        'user.findFirst',
        'ownerRequest.findFirst',
        'ownerRequest.create',
        'auditLog.create',
    ]);

    const createArgs = calls[3].args as { data: Record<string, unknown> };
    assert.equal(createArgs.data.userId, applicantId);
    assert.equal(createArgs.data.companyAddress, 'Bengaluru');
    assert.equal(createArgs.data.businessRegistrationUrl, 'https://evidence.example/registration');
    assert.equal(createArgs.data.identityProofUrl, 'https://evidence.example/identity');

    const auditArgs = calls[4].args as { data: Record<string, unknown> };
    assert.equal(auditArgs.data.entityId, requestId);
    assert.equal(auditArgs.data.targetId, applicantId);
});

test('owner submission rejects affiliated applicants before creating a request', async () => {
    useDeterministicPublicIds();
    let writeCount = 0;
    const transactionClient = {
        $executeRaw: async () => [],
        user: {
            findFirst: async () => ({ id: applicantId, orgId: organizationId, role: 'STAFF' }),
        },
        ownerRequest: {
            findFirst: async () => null,
            create: async () => { writeCount += 1; return {}; },
        },
        auditLog: {
            create: async () => { writeCount += 1; return {}; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().requestOwnership(applicantId, 'Acme Construction'),
        (error) => assertAppError(error, { code: 'COMPANY_CONTEXT_CONFLICT', status: 409 }),
    );
    assert.equal(writeCount, 0);
});

test('owner submission rejects a second pending request without writing audit data', async () => {
    useDeterministicPublicIds();
    let writeCount = 0;
    const transactionClient = {
        $executeRaw: async () => [],
        user: {
            findFirst: async () => ({ id: applicantId, orgId: null, role: 'STAFF' }),
        },
        ownerRequest: {
            findFirst: async () => ({ id: requestId }),
            create: async () => { writeCount += 1; return {}; },
        },
        auditLog: {
            create: async () => { writeCount += 1; return {}; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().requestOwnership(applicantId, 'Acme Construction'),
        (error) => assertAppError(error, { code: 'DUPLICATE_REQUEST', status: 409 }),
    );
    assert.equal(writeCount, 0);
});

test('owner submission retries serialization conflicts and returns a stable conflict after exhaustion', async () => {
    useDeterministicPublicIds();
    let attempts = 0;
    mutablePrisma.$transaction = (async () => {
        attempts += 1;
        throw { code: 'P2034' };
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().requestOwnership(applicantId, 'Acme Construction'),
        (error) => assertAppError(error, { code: 'OWNER_REQUEST_CONFLICT', status: 409 }),
    );
    assert.equal(attempts, 3);
});

test('owner approval commits request, organization, user, notification, and audit in one transaction', async () => {
    useDeterministicPublicIds();
    const calls: Array<{ operation: string; args?: unknown }> = [];
    const pendingRequest = {
        id: requestId,
        userId: applicantId,
        companyName: 'Acme Construction',
        gstin: '29ABCDE1234F1Z5',
        status: 'PENDING',
        user: {
            id: applicantId,
            deletedAt: null,
            isActive: true,
            isDisabled: false,
            orgId: null,
            role: 'STAFF',
            publicId: null,
        },
    };
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => pendingRequest,
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'ownerRequest.updateMany', args });
                return { count: 1 };
            },
            findUniqueOrThrow: async () => ({ ...pendingRequest, status: 'APPROVED' }),
        },
        organization: {
            create: async (args: unknown) => {
                calls.push({ operation: 'organization.create', args });
                return { id: organizationId, name: pendingRequest.companyName };
            },
        },
        user: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
            findUniqueOrThrow: async () => ({ ...pendingRequest.user, role: 'OWNER', orgId: organizationId }),
        },
        notification: {
            create: async (args: unknown) => {
                calls.push({ operation: 'notification.create', args });
                return {};
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await new OwnerService().approveRequest(requestId, reviewerId) as {
        organization: { id: string };
        user: { role: string; orgId: string };
    };

    assert.equal(result.organization.id, organizationId);
    assert.equal(result.user.role, 'OWNER');
    assert.equal(result.user.orgId, organizationId);
    assert.deepEqual(calls.map((call) => call.operation), [
        'ownerRequest.updateMany',
        'organization.create',
        'user.updateMany',
        'notification.create',
        'auditLog.create',
    ]);

    const notificationArgs = calls[3].args as { data: Record<string, unknown> };
    assert.equal(notificationArgs.data.userId, applicantId);
    assert.equal(notificationArgs.data.orgId, organizationId);
    const auditArgs = calls[4].args as { data: Record<string, unknown> };
    assert.equal(auditArgs.data.userId, reviewerId);
    assert.equal(auditArgs.data.targetId, applicantId);
});

test('owner approval fails closed when the request is missing', async () => {
    useDeterministicPublicIds();
    let sideEffectCount = 0;
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => null,
            updateMany: async () => ({ count: 1 }),
        },
        organization: { create: async () => { sideEffectCount += 1; return {}; } },
        user: { updateMany: async () => { sideEffectCount += 1; return { count: 1 }; } },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().approveRequest(requestId, reviewerId),
        (error) => assertAppError(error, { code: 'OWNER_REQUEST_NOT_FOUND', status: 404 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('owner approval rejects an applicant who becomes affiliated before commit', async () => {
    useDeterministicPublicIds();
    let sideEffectCount = 0;
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => ({
                id: requestId,
                userId: applicantId,
                companyName: 'Acme Construction',
                status: 'PENDING',
                user: {
                    deletedAt: null,
                    isActive: true,
                    isDisabled: false,
                    orgId: organizationId,
                    role: 'STAFF',
                },
            }),
            updateMany: async () => ({ count: 1 }),
        },
        organization: { create: async () => { sideEffectCount += 1; return {}; } },
        user: { updateMany: async () => { sideEffectCount += 1; return { count: 1 }; } },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().approveRequest(requestId, reviewerId),
        (error) => assertAppError(error, { code: 'OWNER_APPLICANT_INELIGIBLE', status: 409 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('a losing concurrent owner approval creates no company, notification, or audit', async () => {
    useDeterministicPublicIds();
    let sideEffectCount = 0;
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => ({
                id: requestId,
                userId: applicantId,
                companyName: 'Acme Construction',
                gstin: null,
                status: 'PENDING',
                user: {
                    deletedAt: null,
                    isActive: true,
                    isDisabled: false,
                    orgId: null,
                    role: 'STAFF',
                    publicId: null,
                },
            }),
            updateMany: async () => ({ count: 0 }),
        },
        organization: { create: async () => { sideEffectCount += 1; return {}; } },
        user: { updateMany: async () => { sideEffectCount += 1; return { count: 1 }; } },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().approveRequest(requestId, reviewerId),
        (error) => assertAppError(error, { code: 'OWNER_REQUEST_INVALID_STATE', status: 409 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('a losing concurrent owner rejection creates no notification or audit', async () => {
    let sideEffectCount = 0;
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => ({
                id: requestId,
                userId: applicantId,
                companyName: 'Acme Construction',
                status: 'PENDING',
            }),
            updateMany: async () => ({ count: 0 }),
        },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new OwnerService().rejectRequest(requestId, reviewerId, 'Duplicate review'),
        (error) => assertAppError(error, { code: 'OWNER_REQUEST_INVALID_STATE', status: 409 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('owner rejection conditionally writes the decision, notification, and audit', async () => {
    const calls: Array<{ operation: string; args?: unknown }> = [];
    const transactionClient = {
        ownerRequest: {
            findFirst: async () => ({
                id: requestId,
                userId: applicantId,
                companyName: 'Acme Construction',
                status: 'PENDING',
            }),
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'ownerRequest.updateMany', args });
                return { count: 1 };
            },
            findUniqueOrThrow: async () => ({ id: requestId, status: 'REJECTED' }),
        },
        notification: {
            create: async (args: unknown) => {
                calls.push({ operation: 'notification.create', args });
                return {};
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await new OwnerService().rejectRequest(requestId, reviewerId, '  Missing evidence  ');

    assert.deepEqual(calls.map((call) => call.operation), [
        'ownerRequest.updateMany',
        'notification.create',
        'auditLog.create',
    ]);
    const transitionArgs = calls[0].args as { data: Record<string, unknown> };
    assert.equal(transitionArgs.data.deleteReason, 'Missing evidence');
    const notificationArgs = calls[1].args as { data: Record<string, unknown> };
    assert.equal(notificationArgs.data.deepLink, '/app/promotion-status');
});
