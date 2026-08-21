import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from '../lib/app-error.js';
import { AuthService } from '../lib/auth-service.js';
import { prisma } from '../lib/prisma.js';
import { RolePermissions } from '../lib/permissions.js';
import { InvitationService } from './invitation.service.js';
import { JoinService } from './join.service.js';
import { StaffService } from './staff.service.js';
import { RequestStatus, UserRole, InvitationStatus } from '../../generated/prisma/index.js';

const userDelegate = prisma.user as unknown as {
    findUnique: typeof prisma.user.findUnique;
    findFirst: typeof prisma.user.findFirst;
    updateMany: typeof prisma.user.updateMany;
};
const sessionDelegate = prisma.session as unknown as {
    updateMany: typeof prisma.session.updateMany;
};
const invitationDelegate = prisma.invitation as unknown as {
    findFirst: typeof prisma.invitation.findFirst;
};
const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const original = {
    userFindUnique: userDelegate.findUnique,
    userFindFirst: userDelegate.findFirst,
    userUpdateMany: userDelegate.updateMany,
    sessionUpdateMany: sessionDelegate.updateMany,
    invitationFindFirst: invitationDelegate.findFirst,
    transaction: mutablePrisma.$transaction,
};

function assertAppError(error: unknown, code: string, status: number): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, code);
    assert.equal(error.status, status);
    return true;
}

afterEach(() => {
    userDelegate.findUnique = original.userFindUnique;
    userDelegate.findFirst = original.userFindFirst;
    userDelegate.updateMany = original.userUpdateMany;
    sessionDelegate.updateMany = original.sessionUpdateMany;
    invitationDelegate.findFirst = original.invitationFindFirst;
    mutablePrisma.$transaction = original.transaction;
});

test('invitation acceptance rejects an authenticated account whose email does not own the invitation', async () => {
    let invitationWrites = 0;
    const transactionClient = {
        invitation: {
            findUnique: async () => ({
                id: 'invitation-id',
                orgId: 'org-id',
                email: 'invited@example.com',
                role: UserRole.STAFF,
                status: InvitationStatus.PENDING,
                expiresAt: new Date(Date.now() + 60_000),
            }),
            updateMany: async () => { invitationWrites += 1; return { count: 1 }; },
        },
        user: {
            findUnique: async () => ({ id: 'user-id', email: 'other@example.com', orgId: null }),
            updateMany: async () => { invitationWrites += 1; return { count: 1 }; },
        },
        session: { updateMany: async () => { invitationWrites += 1; return { count: 1 }; } },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new InvitationService().acceptInvitation('invitation-id', 'user-id'),
        (error) => assertAppError(error, 'INVITATION_EMAIL_MISMATCH', 403),
    );
    assert.equal(invitationWrites, 0);
});

test('join rejection cannot transition a request from another organization', async () => {
    let updateArgs: unknown;
    const transactionClient = {
        companyJoinRequest: {
            updateMany: async (args: unknown) => {
                updateArgs = args;
                return { count: 0 };
            },
            findUnique: async () => null,
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new JoinService().rejectRequest('org-a', 'request-from-org-b', 'reviewer-id'),
        (error) => assertAppError(error, 'INVALID_REQUEST', 400),
    );
    assert.deepEqual(updateArgs, {
        where: { id: 'request-from-org-b', orgId: 'org-a', status: RequestStatus.PENDING },
        data: {
            status: RequestStatus.REJECTED,
            resolvedById: 'reviewer-id',
            resolvedAt: updateArgs && (updateArgs as { data: { resolvedAt: Date } }).data.resolvedAt,
        },
    });
});

test('join approval fails when the applicant became affiliated before commit', async () => {
    let writeCount = 0;
    const transactionClient = {
        companyJoinRequest: {
            findFirst: async () => ({
                id: 'request-id',
                orgId: 'org-id',
                userId: 'user-id',
                status: RequestStatus.PENDING,
            }),
            updateMany: async () => { writeCount += 1; return { count: 1 }; },
        },
        user: {
            findUnique: async () => ({ id: 'user-id', orgId: 'other-org' }),
            updateMany: async () => { writeCount += 1; return { count: 1 }; },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new JoinService().approveRequest('org-id', 'request-id', 'reviewer-id'),
        (error) => assertAppError(error, 'AFFILIATION_CONFLICT', 409),
    );
    assert.equal(writeCount, 0);
});

test('staff restoration scopes both the target lookup and write to the requested organization', async () => {
    const calls: Array<{ operation: string; args: unknown }> = [];
    const transactionClient = {
        user: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'user.findFirst', args });
                return { id: 'user-id', orgId: 'org-id', role: UserRole.STAFF };
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'user.updateMany', args });
                return { count: 1 };
            },
            findUnique: async () => ({ id: 'user-id', orgId: 'org-id', role: UserRole.STAFF, isDisabled: false }),
        },
        session: {
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'session.updateMany', args });
                return { count: 1 };
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) => callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await new StaffService().restoreStaff('org-id', 'user-id', 'reviewer-id');

    assert.deepEqual(calls[0], { operation: 'user.findFirst', args: { where: { id: 'user-id', orgId: 'org-id' } } });
    assert.deepEqual(calls[1], {
        operation: 'user.updateMany',
        args: { where: { id: 'user-id', orgId: 'org-id' }, data: { isDisabled: false } },
    });
    assert.deepEqual(calls[2], {
        operation: 'session.updateMany',
        args: { where: { userId: 'user-id', revokedAt: null }, data: { revokedAt: calls[2] && (calls[2].args as { data: { revokedAt: Date } }).data.revokedAt } },
    });
});

test('permission map covers every persisted organization role and keeps unknown roles empty', () => {
    for (const role of [UserRole.OWNER, UserRole.ADMIN, UserRole.SUPERVISOR, UserRole.ACCOUNTANT, UserRole.STAFF, UserRole.VIEWER, UserRole.SUPER_ADMIN]) {
        assert.ok(Array.isArray(RolePermissions[role]), `${role} must have an explicit permission set`);
    }
    assert.deepEqual(RolePermissions.MANAGER, undefined);
    assert.deepEqual(RolePermissions.WORKER, undefined);
});

test('Owner self-service deletion refuses before opening a transaction', async () => {
    userDelegate.findUnique = (async () => ({ id: 'owner-id', orgId: 'org-id', role: UserRole.OWNER })) as unknown as typeof prisma.user.findUnique;
    let transactionStarted = false;
    mutablePrisma.$transaction = (async () => {
        transactionStarted = true;
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AuthService().deleteAccount('owner-id'),
        (error) => assertAppError(error, 'OWNER_ORGANIZATION_REQUIRES_ADMIN_ACTION', 409),
    );
    assert.equal(transactionStarted, false);
});

void userDelegate.findFirst;
void userDelegate.updateMany;
void sessionDelegate.updateMany;
void invitationDelegate.findFirst;
