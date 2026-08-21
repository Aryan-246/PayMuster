import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import type { User } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { AdminService } from './admin.service.js';

const userDelegate = prisma.user as unknown as {
    findUnique: typeof prisma.user.findUnique;
};
const organizationDelegate = prisma.organization as unknown as {
    findMany: (args: unknown) => Promise<unknown[]>;
    count: (args: unknown) => Promise<number>;
    findFirst: (args: unknown) => Promise<unknown>;
};
const siteDelegate = prisma.site as unknown as {
    findMany: (args: unknown) => Promise<unknown[]>;
    count: (args: unknown) => Promise<number>;
};
const auditLogDelegate = prisma.auditLog as unknown as {
    findMany: (args: unknown) => Promise<unknown[]>;
};
const attendanceDelegate = prisma.attendanceRecord as unknown as {
    findMany: (args: unknown) => Promise<unknown[]>;
    count: (args: unknown) => Promise<number>;
    groupBy: (args: unknown) => Promise<Array<{ status: string; _count: { _all: number } }>>;
    findFirst: (args: unknown) => Promise<unknown>;
};
const payrollDelegate = prisma.payRun as unknown as {
    findMany: (args: unknown) => Promise<unknown[]>;
    aggregate: (args: unknown) => Promise<{ _count: { _all: number }; _sum: { totalAmount: unknown } }>;
    count: (args: unknown) => Promise<number>;
    findFirst: (args: unknown) => Promise<unknown>;
};
const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const originalFindUnique = userDelegate.findUnique;
const originalOrganizationFindMany = organizationDelegate.findMany;
const originalOrganizationCount = organizationDelegate.count;
const originalOrganizationFindFirst = organizationDelegate.findFirst;
const originalSiteFindMany = siteDelegate.findMany;
const originalSiteCount = siteDelegate.count;
const originalAuditLogFindMany = auditLogDelegate.findMany;
const originalTransaction = mutablePrisma.$transaction;
const originalAttendanceFindMany = attendanceDelegate.findMany;
const originalAttendanceCount = attendanceDelegate.count;
const originalAttendanceGroupBy = attendanceDelegate.groupBy;
const originalAttendanceFindFirst = attendanceDelegate.findFirst;
const originalPayrollFindMany = payrollDelegate.findMany;
const originalPayrollAggregate = payrollDelegate.aggregate;
const originalPayrollCount = payrollDelegate.count;
const originalPayrollFindFirst = payrollDelegate.findFirst;

const targetUser: User = {
    id: '11111111-1111-4111-8111-111111111111',
    orgId: '22222222-2222-4222-8222-222222222222',
    email: 'worker@example.com',
    phone: null,
    passwordHash: 'stored-hash',
    role: 'STAFF',
    firstName: 'Test',
    lastName: 'Worker',
    isActive: true,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    deletedAt: null,
    avatarUrl: null,
    avatarStorageKey: null,
    deleteReason: null,
    deletedBy: null,
    emailVerified: true,
    isDisabled: false,
    lastLoginAt: new Date('2026-01-02T00:00:00.000Z'),
    provider: 'email',
    status: 'VERIFIED',
    publicId: 'PM-USR-000001',
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

afterEach(() => {
    userDelegate.findUnique = originalFindUnique;
    organizationDelegate.findMany = originalOrganizationFindMany;
    organizationDelegate.count = originalOrganizationCount;
    organizationDelegate.findFirst = originalOrganizationFindFirst;
    siteDelegate.findMany = originalSiteFindMany;
    siteDelegate.count = originalSiteCount;
    auditLogDelegate.findMany = originalAuditLogFindMany;
    attendanceDelegate.findMany = originalAttendanceFindMany;
    attendanceDelegate.count = originalAttendanceCount;
    attendanceDelegate.groupBy = originalAttendanceGroupBy;
    attendanceDelegate.findFirst = originalAttendanceFindFirst;
    payrollDelegate.findMany = originalPayrollFindMany;
    payrollDelegate.aggregate = originalPayrollAggregate;
    payrollDelegate.count = originalPayrollCount;
    payrollDelegate.findFirst = originalPayrollFindFirst;
    mutablePrisma.$transaction = originalTransaction;
});

test('Admin deletion requires a nonblank reason before starting a transaction', async () => {
    userDelegate.findUnique = (async () => targetUser) as unknown as typeof prisma.user.findUnique;
    let transactionStarted = false;
    mutablePrisma.$transaction = (async () => {
        transactionStarted = true;
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().executeAction(
            targetUser.id,
            '33333333-3333-4333-8333-333333333333',
            'DELETE',
            undefined,
            { reason: '   ' },
        ),
        (error) => assertAppError(error, { code: 'REASON_REQUIRED', status: 400 }),
    );
    assert.equal(transactionStarted, false);
});

test('generic role changes cannot assign the Super Admin role', async () => {
    userDelegate.findUnique = (async () => targetUser) as unknown as typeof prisma.user.findUnique;

    await assert.rejects(
        new AdminService().executeAction(
            targetUser.id,
            '33333333-3333-4333-8333-333333333333',
            'CHANGE_ROLE',
            'SUPER_ADMIN',
        ),
        (error) => assertAppError(error, { code: 'FORBIDDEN', status: 403 }),
    );
});

test('Admin deletion tombstones only the identity and writes revocation and audit operations in one transaction', async () => {
    userDelegate.findUnique = (async () => targetUser) as unknown as typeof prisma.user.findUnique;
    const calls: Array<{ operation: string; args: unknown }> = [];
    const transactionClient = {
        user: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
        },
        session: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'session.updateMany', args });
                return { count: 2 };
            },
        },
        authOtp: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'authOtp.updateMany', args });
                return { count: 1 };
            },
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
    let transactionCount = 0;
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => {
        transactionCount += 1;
        return callback(transactionClient);
    }) as unknown as typeof prisma.$transaction;

    const actorId = '33333333-3333-4333-8333-333333333333';
    const result = (await new AdminService().executeAction(
        targetUser.id,
        actorId,
        'DELETE',
        undefined,
        {
            reason: '  Confirmed policy violation  ',
            requestId: 'request-123',
            ipAddress: '203.0.113.10',
            userAgent: 'PayMuster-Test/1.0',
        },
    )) as { message: string; deletedAt: string };

    assert.equal(transactionCount, 1);
    assert.deepEqual(
        calls.map((call) => call.operation),
        [
            'user.updateMany',
            'session.updateMany',
            'authOtp.updateMany',
            'notification.create',
            'auditLog.create',
        ],
    );
    assert.equal(result.message, 'User account deleted');

    const notificationArgs = calls[3].args as {
        data: {
            orgId: string;
            userId: string;
            title: string;
            body: string;
            type: string;
            deepLink: string | null;
        };
    };
    assert.equal(notificationArgs.data.orgId, targetUser.orgId);
    assert.equal(notificationArgs.data.userId, targetUser.id);
    assert.equal(notificationArgs.data.title, 'Account Deleted');
    assert.equal(notificationArgs.data.body, 'Your PayMuster account has been deleted by an administrator.');
    assert.equal(notificationArgs.data.type, 'USER_DELETION');
    assert.equal(notificationArgs.data.deepLink, null);

    const identityArgs = calls[0].args as {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
    };
    assert.equal(identityArgs.where.id, targetUser.id);
    assert.equal(identityArgs.data.status, 'DELETED');
    assert.equal(identityArgs.data.isActive, false);
    assert.equal(identityArgs.data.isDisabled, true);
    assert.equal(identityArgs.data.deleteReason, 'Confirmed policy violation');
    assert.equal(identityArgs.data.deletedBy, actorId);
    assert.equal('orgId' in identityArgs.data, false);
    assert.equal('email' in identityArgs.data, false);

    const auditArgs = calls[4].args as {
        data: {
            orgId: string;
            userId: string;
            entityId: string;
            targetId: string;
            requestId: string;
            ipAddress: string;
            userAgent: string;
            changes: Record<string, unknown>;
            beforeValue: Record<string, unknown>;
            afterValue: Record<string, unknown>;
        };
    };
    assert.equal(auditArgs.data.orgId, targetUser.orgId);
    assert.equal(auditArgs.data.userId, actorId);
    assert.equal(auditArgs.data.entityId, targetUser.id);
    assert.equal(auditArgs.data.targetId, targetUser.id);
    assert.equal(auditArgs.data.requestId, 'request-123');
    assert.equal(auditArgs.data.ipAddress, '203.0.113.10');
    assert.equal(auditArgs.data.userAgent, 'PayMuster-Test/1.0');
    assert.equal(auditArgs.data.changes.reason, 'Confirmed policy violation');
    assert.equal(auditArgs.data.changes.organizationPreserved, true);
    assert.equal(auditArgs.data.changes.businessHistoryPreserved, true);
    assert.equal(auditArgs.data.beforeValue.orgId, targetUser.orgId);
    assert.equal(auditArgs.data.afterValue.orgId, targetUser.orgId);
    assert.equal(auditArgs.data.afterValue.status, 'DELETED');
});

test('a concurrent duplicate deletion fails with a conflict inside the transaction', async () => {
    userDelegate.findUnique = (async () => targetUser) as unknown as typeof prisma.user.findUnique;
    const transactionClient = {
        user: { updateMany: async () => ({ count: 0 }) },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().executeAction(
            targetUser.id,
            '33333333-3333-4333-8333-333333333333',
            'DELETE',
            undefined,
            { reason: 'Duplicate request' },
        ),
        (error) => assertAppError(error, { code: 'CONFLICT', status: 409 }),
    );
});

test('document verification completes an explicitly claimed review with notification and audit', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const documentId = '44444444-4444-4444-8444-444444444444';
    const staffId = '55555555-5555-4555-8555-555555555555';
    const recipientId = '66666666-6666-4666-8666-666666666666';
    const transactionClient = {
        staffDocument: {
            findFirst: async () => ({
                id: documentId,
                orgId: targetUser.orgId,
                staffId,
                type: 'Identity Proof',
                status: 'UNDER_REVIEW',
                reviewerId: targetUser.id,
                staff: { email: targetUser.email },
            }),
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'staffDocument.updateMany', args });
                return { count: 1 };
            },
            findUniqueOrThrow: async (args: unknown) => {
                calls.push({ operation: 'staffDocument.findUniqueOrThrow', args });
                return { id: documentId, status: 'VERIFIED' };
            },
        },
        user: {
            findMany: async (args: unknown) => {
                calls.push({ operation: 'user.findMany', args });
                return [{ id: recipientId }];
            },
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
    let transactionCount = 0;
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => {
        transactionCount += 1;
        return callback(transactionClient);
    }) as unknown as typeof prisma.$transaction;

    const result = await new AdminService().verifyDocument(documentId, targetUser.id) as {
        id: string;
        status: string;
    };

    assert.equal(transactionCount, 1);
    assert.equal(result.status, 'VERIFIED');
    assert.deepEqual(calls.map((call) => call.operation), [
        'staffDocument.updateMany',
        'user.findMany',
        'notification.create',
        'auditLog.create',
        'staffDocument.findUniqueOrThrow',
    ]);

    const transition = calls[0].args as {
        where: { status: string; reviewerId: string };
        data: { status: string; reviewerId: string; reviewedAt: Date };
    };
    assert.equal(transition.where.status, 'UNDER_REVIEW');
    assert.equal(transition.where.reviewerId, targetUser.id);
    assert.equal(transition.data.status, 'VERIFIED');
    assert.equal(transition.data.reviewerId, targetUser.id);
    assert.ok(transition.data.reviewedAt instanceof Date);

    const notification = calls[2].args as {
        data: { userId: string; orgId: string; type: string };
    };
    assert.equal(notification.data.userId, recipientId);
    assert.equal(notification.data.orgId, targetUser.orgId);
    assert.equal(notification.data.type, 'DOCUMENT_REVIEW');

    const audit = calls[3].args as {
        data: { userId: string; entityId: string; targetId: string; changes: Record<string, unknown> };
    };
    assert.equal(audit.data.userId, targetUser.id);
    assert.equal(audit.data.entityId, documentId);
    assert.equal(audit.data.targetId, staffId);
    assert.equal(audit.data.changes.notificationDelivered, true);
});

test('a losing concurrent document review writes no notification or audit', async () => {
    let sideEffectCount = 0;
    const transactionClient = {
        staffDocument: {
            findFirst: async () => ({
                id: '44444444-4444-4444-8444-444444444444',
                orgId: targetUser.orgId,
                staffId: '55555555-5555-4555-8555-555555555555',
                type: 'Identity Proof',
                status: 'UNDER_REVIEW',
                reviewerId: targetUser.id,
                staff: { email: targetUser.email },
            }),
            updateMany: async () => ({ count: 0 }),
        },
        user: { findMany: async () => { sideEffectCount += 1; return []; } },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().rejectDocument(
            '44444444-4444-4444-8444-444444444444',
            targetUser.id,
            'Unreadable image',
        ),
        (error) => assertAppError(error, { code: 'DOCUMENT_INVALID_STATE', status: 409 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('document review completion rejects an unclaimed document without side effects', async () => {
    let mutationCount = 0;
    const transactionClient = {
        staffDocument: {
            findFirst: async () => ({
                id: '44444444-4444-4444-8444-444444444444',
                orgId: targetUser.orgId,
                staffId: '55555555-5555-4555-8555-555555555555',
                type: 'Identity Proof',
                status: 'PENDING_REVIEW',
                reviewerId: null,
                staff: { email: targetUser.email },
            }),
            updateMany: async () => { mutationCount += 1; return { count: 1 }; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().verifyDocument(
            '44444444-4444-4444-8444-444444444444',
            targetUser.id,
        ),
        (error) => assertAppError(error, { code: 'DOCUMENT_INVALID_STATE', status: 409 }),
    );
    assert.equal(mutationCount, 0);
});

test('document claim conditionally records reviewer and prior state in one transaction', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const documentId = '44444444-4444-4444-8444-444444444444';
    const staffId = '55555555-5555-4555-8555-555555555555';
    const transactionClient = {
        staffDocument: {
            findFirst: async () => ({
                id: documentId,
                orgId: targetUser.orgId,
                staffId,
                status: 'PENDING_REVIEW',
            }),
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'staffDocument.updateMany', args });
                return { count: 1 };
            },
            findUniqueOrThrow: async () => ({
                id: documentId,
                status: 'UNDER_REVIEW',
                reviewerId: targetUser.id,
            }),
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

    const result = await new AdminService().claimDocument(documentId, targetUser.id) as {
        status: string;
        reviewerId: string;
    };
    assert.equal(result.status, 'UNDER_REVIEW');
    assert.equal(result.reviewerId, targetUser.id);
    const transition = calls[0].args as {
        where: { status: string };
        data: { status: string; reviewerId: string };
    };
    assert.equal(transition.where.status, 'PENDING_REVIEW');
    assert.equal(transition.data.status, 'UNDER_REVIEW');
    assert.equal(transition.data.reviewerId, targetUser.id);
    const audit = calls[1].args as { data: { changes: Record<string, unknown> } };
    assert.equal(audit.data.changes.previousStatus, 'PENDING_REVIEW');
    assert.equal(audit.data.changes.status, 'UNDER_REVIEW');
});

test('Admin password reset uses transaction-current identity state and commits revocation, notification, and audit', async () => {
    const transactionOrgId = '77777777-7777-4777-8777-777777777777';
    const currentUser = { ...targetUser, orgId: transactionOrgId };
    const calls: Array<{ operation: string; args: any }> = [];
    const transactionClient = {
        user: {
            findUnique: async (args: unknown) => {
                calls.push({ operation: 'user.findUnique', args });
                return currentUser;
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
        },
        session: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'session.updateMany', args });
                return { count: 2 };
            },
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

    const result = await new AdminService().resetPassword(
        targetUser.id,
        '33333333-3333-4333-8333-333333333333',
    );

    assert.match(result.tempPassword, /^Pm-[0-9a-f]{36}$/);
    assert.deepEqual(calls.map((call) => call.operation), [
        'user.findUnique',
        'user.updateMany',
        'session.updateMany',
        'notification.create',
        'auditLog.create',
    ]);
    assert.equal(calls[1].args.where.orgId, transactionOrgId);
    assert.equal(calls[1].args.where.role, targetUser.role);
    assert.equal(calls[1].args.where.status, targetUser.status);
    assert.equal(calls[1].args.where.isDisabled, false);
    assert.notEqual(calls[1].args.data.passwordHash, targetUser.passwordHash);
    assert.equal(calls[3].args.data.orgId, transactionOrgId);
    assert.equal(calls[4].args.data.orgId, transactionOrgId);
});

test('a losing concurrent password reset writes no session, notification, or audit side effects', async () => {
    let sideEffectCount = 0;
    const transactionClient = {
        user: {
            findUnique: async () => targetUser,
            updateMany: async () => ({ count: 0 }),
        },
        session: { updateMany: async () => { sideEffectCount += 1; return { count: 0 }; } },
        notification: { create: async () => { sideEffectCount += 1; return {}; } },
        auditLog: { create: async () => { sideEffectCount += 1; return {}; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().resetPassword(targetUser.id, '33333333-3333-4333-8333-333333333333'),
        (error) => assertAppError(error, { code: 'CONFLICT', status: 409 }),
    );
    assert.equal(sideEffectCount, 0);
});

test('Admin role changes reject disabled targets before mutation', async () => {
    const disabledUser = { ...targetUser, isDisabled: true, status: 'SUSPENDED' as const };
    userDelegate.findUnique = (async () => disabledUser) as unknown as typeof prisma.user.findUnique;
    let mutationCount = 0;
    const transactionClient = {
        user: {
            findUnique: async () => disabledUser,
            updateMany: async () => { mutationCount += 1; return { count: 1 }; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().executeAction(
            targetUser.id,
            '33333333-3333-4333-8333-333333333333',
            'CHANGE_ROLE',
            'SUPERVISOR',
        ),
        (error) => assertAppError(error, { code: 'CONFLICT', status: 409 }),
    );
    assert.equal(mutationCount, 0);
});

test('Admin suspension rejects pending accounts instead of implicitly verifying them on restore', async () => {
    const pendingUser = { ...targetUser, emailVerified: false, status: 'PENDING' as const };
    userDelegate.findUnique = (async () => pendingUser) as unknown as typeof prisma.user.findUnique;
    let mutationCount = 0;
    const transactionClient = {
        user: {
            findUnique: async () => pendingUser,
            updateMany: async () => { mutationCount += 1; return { count: 1 }; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AdminService().executeAction(
            targetUser.id,
            '33333333-3333-4333-8333-333333333333',
            'SUSPEND',
        ),
        (error) => assertAppError(error, { code: 'CONFLICT', status: 409 }),
    );
    assert.equal(mutationCount, 0);
});

test('Admin block commits the exact state, revokes sessions, and emits block-specific records', async () => {
    userDelegate.findUnique = (async () => targetUser) as unknown as typeof prisma.user.findUnique;
    const calls: Array<{ operation: string; args: any }> = [];
    const blockedUser = { ...targetUser, isDisabled: true, status: 'BLOCKED' as const };
    const transactionClient = {
        user: {
            findUnique: async (args: unknown) => {
                calls.push({ operation: 'user.findUnique', args });
                return calls.length === 1 ? targetUser : blockedUser;
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
        },
        session: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'session.updateMany', args });
                return { count: 1 };
            },
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

    const result = await new AdminService().executeAction(
        targetUser.id,
        '33333333-3333-4333-8333-333333333333',
        'BLOCK',
    ) as User;

    assert.equal(result.status, 'BLOCKED');
    assert.deepEqual(calls.map((call) => call.operation), [
        'user.findUnique',
        'user.updateMany',
        'session.updateMany',
        'notification.create',
        'auditLog.create',
        'user.findUnique',
    ]);
    assert.equal(calls[1].args.where.orgId, targetUser.orgId);
    assert.equal(calls[1].args.where.status, 'VERIFIED');
    assert.equal(calls[1].args.data.status, 'BLOCKED');
    assert.equal(calls[3].args.data.title, 'Account Blocked');
    assert.equal(calls[3].args.data.body, 'Your account has been blocked.');
    assert.equal(calls[4].args.data.changes.sessionsRevoked, true);
});

test('Admin restore accepts only disabled suspended or blocked accounts and does not revoke sessions again', async () => {
    const blockedUser = { ...targetUser, isDisabled: true, status: 'BLOCKED' as const };
    const restoredUser = { ...targetUser, isDisabled: false, status: 'VERIFIED' as const };
    userDelegate.findUnique = (async () => blockedUser) as unknown as typeof prisma.user.findUnique;
    const calls: Array<{ operation: string; args: any }> = [];
    let findCount = 0;
    const transactionClient = {
        user: {
            findUnique: async (args: unknown) => {
                calls.push({ operation: 'user.findUnique', args });
                findCount += 1;
                return findCount === 1 ? blockedUser : restoredUser;
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
        },
        session: {
            updateMany: async () => {
                calls.push({ operation: 'session.updateMany', args: {} });
                return { count: 1 };
            },
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

    const result = await new AdminService().executeAction(
        targetUser.id,
        '33333333-3333-4333-8333-333333333333',
        'RESTORE',
    ) as User;

    assert.equal(result.status, 'VERIFIED');
    assert.equal(calls.some((call) => call.operation === 'session.updateMany'), false);
    assert.equal(calls[1].args.where.status, 'BLOCKED');
    assert.equal(calls[1].args.where.isDisabled, true);
    assert.equal(calls[1].args.data.status, 'VERIFIED');
    assert.equal(calls[2].args.data.title, 'Account Restored');
    assert.equal(calls[3].args.data.changes.sessionsRevoked, false);
});

test('Admin company list keeps owners, counts, and pagination scoped to active rows', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const company = { id: 'org-1', deletedAt: null };

    organizationDelegate.findMany = (async (args: any) => {
        calls.push({ operation: 'findMany', args });
        return [company];
    }) as typeof organizationDelegate.findMany;
    organizationDelegate.count = (async (args: any) => {
        calls.push({ operation: 'count', args });
        return 1;
    }) as typeof organizationDelegate.count;

    const result = await new AdminService().getCompanies('Acme', 2, 10);

    assert.deepEqual(result.companies, [company]);
    assert.equal(result.total, 1);
    assert.equal(result.page, 2);
    assert.equal(result.totalPages, 1);
    assert.deepEqual(calls[0].args.where, {
        deletedAt: null,
        OR: [
            { name: { contains: 'Acme', mode: 'insensitive' } },
            { publicId: { contains: 'Acme', mode: 'insensitive' } },
            { joinCode: { contains: 'Acme', mode: 'insensitive' } },
            { gstin: { contains: 'Acme', mode: 'insensitive' } },
        ],
    });
    assert.deepEqual(calls[0].args.include.users.where, { role: 'OWNER', deletedAt: null });
    assert.deepEqual(calls[0].args.include._count.select, {
        users: { where: { deletedAt: null } },
        sites: { where: { deletedAt: null } },
        staff: { where: { deletedAt: null } },
        attendanceRecords: { where: { deletedAt: null } },
    });
    assert.equal(calls[0].args.skip, 10);
    assert.equal(calls[0].args.take, 10);
    assert.deepEqual(calls[1].args.where, calls[0].args.where);
});

test('Admin company detail fails closed for deleted organizations and filters active nested evidence', async () => {
    let capturedOrganizationArgs: any;
    let capturedAuditArgs: any;
    const company = { id: 'org-1', deletedAt: null, users: [], sites: [] };

    organizationDelegate.findFirst = (async (args: any) => {
        capturedOrganizationArgs = args;
        return company;
    }) as typeof organizationDelegate.findFirst;
    auditLogDelegate.findMany = (async (args: any) => {
        capturedAuditArgs = args;
        return [];
    }) as typeof auditLogDelegate.findMany;

    const result = await new AdminService().getCompanyDetail('org-1');

    assert.deepEqual(result.company, company);
    assert.deepEqual(capturedOrganizationArgs.where, { id: 'org-1', deletedAt: null });
    assert.deepEqual(capturedOrganizationArgs.include.users.where, { deletedAt: null });
    assert.deepEqual(capturedOrganizationArgs.include.sites.where, { deletedAt: null });
    assert.deepEqual(capturedOrganizationArgs.include._count.select, {
        users: { where: { deletedAt: null } },
        sites: { where: { deletedAt: null } },
        staff: { where: { deletedAt: null } },
        attendanceRecords: { where: { deletedAt: null } },
        payRuns: { where: { deletedAt: null } },
    });
    assert.deepEqual(capturedAuditArgs.where, { orgId: 'org-1' });
});

test('Admin site list excludes deleted organizations and deleted child records from counts', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const site = { id: 'site-1', orgId: 'org-1', deletedAt: null };

    siteDelegate.findMany = (async (args: any) => {
        calls.push({ operation: 'findMany', args });
        return [site];
    }) as typeof siteDelegate.findMany;
    siteDelegate.count = (async (args: any) => {
        calls.push({ operation: 'count', args });
        return 1;
    }) as typeof siteDelegate.count;

    const result = await new AdminService().getSites('HQ', 'org-1', 2, 5);

    assert.deepEqual(result.sites, [site]);
    assert.equal(result.total, 1);
    assert.equal(result.page, 2);
    assert.equal(result.totalPages, 1);
    const expectedWhere = {
        deletedAt: null,
        orgId: 'org-1',
        OR: [
            { name: { contains: 'HQ', mode: 'insensitive' } },
            { address: { contains: 'HQ', mode: 'insensitive' } },
            { publicId: { contains: 'HQ', mode: 'insensitive' } },
        ],
        org: { deletedAt: null },
    };
    assert.deepEqual(calls[0].args.where, expectedWhere);
    assert.deepEqual(calls[1].args.where, expectedWhere);
    assert.deepEqual(calls[0].args.include._count.select, {
        siteAssignments: { where: { deletedAt: null } },
        attendanceRecords: { where: { deletedAt: null } },
        siteMembers: { where: { deletedAt: null } },
    });
    assert.equal(calls[0].args.skip, 5);
    assert.equal(calls[0].args.take, 5);
});

test('Admin attendance list returns real filtered status summaries without changing pagination data', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const record = { id: 'attendance-1', status: 'PRESENT' };

    attendanceDelegate.findMany = (async (args: any) => {
        calls.push({ operation: 'findMany', args });
        return [record];
    }) as typeof attendanceDelegate.findMany;
    attendanceDelegate.count = (async (args: any) => {
        calls.push({ operation: 'count', args });
        return 4;
    }) as typeof attendanceDelegate.count;
    attendanceDelegate.groupBy = (async (args: any) => {
        calls.push({ operation: 'groupBy', args });
        return [
            { status: 'PRESENT', _count: { _all: 2 } },
            { status: 'ABSENT', _count: { _all: 2 } },
        ];
    }) as typeof attendanceDelegate.groupBy;

    const result = await new AdminService().getAttendanceRecords(
        'Acme',
        'org-1',
        'site-1',
        'PRESENT',
        2,
        1,
    );

    assert.deepEqual(result.records, [record]);
    assert.equal(result.total, 4);
    assert.equal(result.page, 2);
    assert.equal(result.totalPages, 4);
    assert.deepEqual(result.summary, {
        total: 4,
        byStatus: { PRESENT: 2, ABSENT: 2 },
    });

    assert.equal(calls.length, 3);
    for (const call of calls) {
        assert.equal(call.args.where.deletedAt, null);
        assert.equal(call.args.where.orgId, 'org-1');
        assert.equal(call.args.where.siteId, 'site-1');
        assert.equal(call.args.where.status, 'PRESENT');
        assert.equal(call.args.where.OR.length, 6);
    }
    assert.equal(calls[0].args.skip, 1);
    assert.equal(calls[0].args.take, 1);
});

test('Admin attendance detail is organization and site scoped and excludes deleted rows', async () => {
    let capturedArgs: any;
    const record = { id: 'attendance-1', orgId: 'org-1', siteId: 'site-1' };
    attendanceDelegate.findFirst = (async (args: any) => {
        capturedArgs = args;
        return record;
    }) as typeof attendanceDelegate.findFirst;

    const result = await new AdminService().getAttendanceDetail('attendance-1', 'org-1', 'site-1');

    assert.deepEqual(result, record);
    assert.deepEqual(capturedArgs.where, {
        id: 'attendance-1',
        deletedAt: null,
        orgId: 'org-1',
        siteId: 'site-1',
    });
    assert.ok(capturedArgs.include.org);
    assert.ok(capturedArgs.include.site);
    assert.ok(capturedArgs.include.staff);
    assert.ok(capturedArgs.include.markedBy);
    assert.ok(capturedArgs.include.correctionRequests);
});

test('Admin payroll list returns real amount and PayCycle status summaries with organization filtering', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    const payRun = { id: 'payrun-1', totalAmount: '1250.50' };

    payrollDelegate.findMany = (async (args: any) => {
        calls.push({ operation: 'findMany', args });
        return [payRun];
    }) as typeof payrollDelegate.findMany;
    payrollDelegate.aggregate = (async (args: any) => {
        calls.push({ operation: 'aggregate', args });
        return { _count: { _all: 4 }, _sum: { totalAmount: '5000.75' } };
    }) as typeof payrollDelegate.aggregate;
    payrollDelegate.count = (async (args: any) => {
        calls.push({ operation: 'count', args });
        return args.where.payCycle.status === 'PAID' ? 2 : 0;
    }) as typeof payrollDelegate.count;

    const result = await new AdminService().getPayrollRecords('org-1', 'PAID', 2, 1);

    assert.deepEqual(result.payRuns, [payRun]);
    assert.equal(result.total, 4);
    assert.equal(result.page, 2);
    assert.equal(result.totalPages, 4);
    assert.deepEqual(result.summary, {
        total: 4,
        totalAmount: '5000.75',
        byStatus: { DRAFT: 0, CALCULATED: 0, APPROVED: 0, PAID: 2 },
    });

    assert.equal(calls.length, 3);
    assert.equal(calls[0].args.where.orgId, 'org-1');
    assert.equal(calls[0].args.where.deletedAt, null);
    assert.equal(calls[0].args.where.payCycle.status, 'PAID');
    assert.equal(calls[0].args.skip, 1);
    assert.equal(calls[0].args.take, 1);
    assert.equal(calls[0].args.include._count.select.payRunItems.where.deletedAt, null);
    for (const call of calls.slice(1)) {
        assert.equal(call.args.where.orgId, 'org-1');
        assert.equal(call.args.where.deletedAt, null);
        assert.equal(call.args.where.payCycle.status, 'PAID');
    }
});

test('Admin payroll detail is organization scoped and includes only active PayRun items', async () => {
    let capturedArgs: any;
    const payRun = { id: 'payrun-1', orgId: 'org-1' };
    payrollDelegate.findFirst = (async (args: any) => {
        capturedArgs = args;
        return payRun;
    }) as typeof payrollDelegate.findFirst;

    const result = await new AdminService().getPayrollDetail('payrun-1', 'org-1');

    assert.deepEqual(result, payRun);
    assert.deepEqual(capturedArgs.where, {
        id: 'payrun-1',
        deletedAt: null,
        orgId: 'org-1',
    });
    assert.deepEqual(capturedArgs.include.payRunItems.where, {
        deletedAt: null,
        orgId: 'org-1',
    });
    assert.ok(capturedArgs.include.org);
    assert.ok(capturedArgs.include.payCycle);
    assert.ok(capturedArgs.include.approvedBy);
    assert.ok(capturedArgs.include.payRunItems.select.staff);
});

test('Admin payroll detail fails closed for missing, deleted, or cross-organization runs', async () => {
    let capturedWhere: any;
    payrollDelegate.findFirst = (async (args: any) => {
        capturedWhere = args.where;
        return null;
    }) as typeof payrollDelegate.findFirst;

    await assert.rejects(
        new AdminService().getPayrollDetail('payrun-1', 'other-org'),
        (error) => assertAppError(error, { code: 'NOT_FOUND', status: 404 }),
    );
    assert.deepEqual(capturedWhere, {
        id: 'payrun-1',
        deletedAt: null,
        orgId: 'other-org',
    });
});

test('Admin attendance detail fails closed for missing, deleted, or cross-organization records', async () => {
    let capturedWhere: any;
    attendanceDelegate.findFirst = (async (args: any) => {
        capturedWhere = args.where;
        return null;
    }) as typeof attendanceDelegate.findFirst;

    await assert.rejects(
        new AdminService().getAttendanceDetail('attendance-1', 'other-org'),
        (error) => assertAppError(error, { code: 'NOT_FOUND', status: 404 }),
    );
    assert.deepEqual(capturedWhere, {
        id: 'attendance-1',
        deletedAt: null,
        orgId: 'other-org',
    });
});
