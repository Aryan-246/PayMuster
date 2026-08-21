import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import jwt from 'jsonwebtoken';

import { AppError } from './app-error.js';
import { AuthService } from './auth-service.js';
import { hashPassword } from './auth-utils.js';
import { prisma } from './prisma.js';

const userDelegate = prisma.user as unknown as {
    findMany: typeof prisma.user.findMany;
    findUnique: typeof prisma.user.findUnique;
    update: typeof prisma.user.update;
};
const sessionDelegate = prisma.session as unknown as {
    create: typeof prisma.session.create;
    findFirst: typeof prisma.session.findFirst;
    updateMany: typeof prisma.session.updateMany;
};
const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};

const originals = {
    userFindMany: userDelegate.findMany,
    userFindUnique: userDelegate.findUnique,
    userUpdate: userDelegate.update,
    sessionCreate: sessionDelegate.create,
    sessionFindFirst: sessionDelegate.findFirst,
    sessionUpdateMany: sessionDelegate.updateMany,
    transaction: mutablePrisma.$transaction,
};

const baseUser = {
    id: '11111111-1111-4111-8111-111111111111',
    orgId: '22222222-2222-4222-8222-222222222222',
    status: 'VERIFIED',
    email: 'person@example.com',
    firstName: 'First',
    lastName: 'User',
    provider: 'email',
    emailVerified: true,
    isActive: true,
    isDisabled: false,
    role: 'STAFF',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
};

const noOpMailer = {
    sendLoginNotificationEmail: async () => undefined,
    sendGoogleLoginNotificationEmail: async () => undefined,
    sendWelcomeEmail: async () => undefined,
};

function maintenanceError(): AppError {
    return new AppError(
        'MAINTENANCE_MODE',
        'PayMuster is temporarily unavailable for maintenance.',
        503,
    );
}

function assertAppError(error: unknown, code: string, status: number): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, code);
    assert.equal(error.status, status);
    return true;
}

afterEach(() => {
    userDelegate.findMany = originals.userFindMany;
    userDelegate.findUnique = originals.userFindUnique;
    userDelegate.update = originals.userUpdate;
    sessionDelegate.create = originals.sessionCreate;
    sessionDelegate.findFirst = originals.sessionFindFirst;
    sessionDelegate.updateMany = originals.sessionUpdateMany;
    mutablePrisma.$transaction = originals.transaction;
});

test('maintenance blocks an ordinary password login before user or session writes', async () => {
    const password = 'UniquePass123!';
    userDelegate.findMany = (async () => [{
        ...baseUser,
        passwordHash: await hashPassword(password),
    }]) as unknown as typeof prisma.user.findMany;

    let userUpdates = 0;
    let sessionCreates = 0;
    userDelegate.update = (async () => {
        userUpdates += 1;
        return baseUser;
    }) as unknown as typeof prisma.user.update;
    sessionDelegate.create = (async () => {
        sessionCreates += 1;
        return {};
    }) as unknown as typeof prisma.session.create;

    const service = new AuthService(
        noOpMailer as never,
        undefined,
        { assertOperational: async () => { throw maintenanceError(); } } as never,
    );

    await assert.rejects(
        service.authenticateEmail({ email: baseUser.email, password, rememberMe: false }, {}),
        (error) => assertAppError(error, 'MAINTENANCE_MODE', 503),
    );
    assert.equal(userUpdates, 0);
    assert.equal(sessionCreates, 0);
});

test('Super Admin login persists one session UUID shared by both issued tokens', async () => {
    const password = 'UniquePass123!';
    const user = {
        ...baseUser,
        role: 'SUPER_ADMIN',
        passwordHash: await hashPassword(password),
    };
    userDelegate.findMany = (async () => [user]) as unknown as typeof prisma.user.findMany;
    userDelegate.update = (async () => user) as unknown as typeof prisma.user.update;

    let persistedSession: { id: string; userId: string } | undefined;
    sessionDelegate.create = (async (args: { data: { id: string; userId: string } }) => {
        persistedSession = args.data;
        return args.data;
    }) as unknown as typeof prisma.session.create;

    const checkedRoles: Array<string | undefined> = [];
    const service = new AuthService(
        noOpMailer as never,
        undefined,
        {
            assertOperational: async (role?: string) => {
                checkedRoles.push(role);
                if (role !== 'SUPER_ADMIN') {
                    throw maintenanceError();
                }
            },
        } as never,
    );

    const result = await service.authenticateEmail(
        { email: user.email, password, rememberMe: true },
        {},
    );
    const accessClaims = service.verifyAccessToken(result.accessToken);
    const refreshClaims = jwt.decode(result.refreshToken) as { sessionId?: string } | null;

    assert.deepEqual(checkedRoles, ['SUPER_ADMIN']);
    assert.ok(persistedSession);
    assert.equal(accessClaims.sessionId, persistedSession.id);
    assert.equal(refreshClaims?.sessionId, persistedSession.id);
    assert.equal(persistedSession.userId, user.id);
});

test('Google authentication performs no existing-user mutation during maintenance', async () => {
    userDelegate.findMany = (async () => [{ ...baseUser, provider: 'google' }]) as unknown as typeof prisma.user.findMany;
    let userUpdates = 0;
    let sessionCreates = 0;
    userDelegate.update = (async () => {
        userUpdates += 1;
        return baseUser;
    }) as unknown as typeof prisma.user.update;
    sessionDelegate.create = (async () => {
        sessionCreates += 1;
        return {};
    }) as unknown as typeof prisma.session.create;

    const googleClient = {
        verifyIdToken: async () => ({
            getPayload: () => ({ email: baseUser.email, email_verified: true, name: 'First User' }),
        }),
    };
    const service = new AuthService(
        noOpMailer as never,
        undefined,
        { assertOperational: async () => { throw maintenanceError(); } } as never,
        googleClient as never,
        'google-client-id',
    );

    await assert.rejects(
        service.authenticateGoogle({ idToken: 'valid-token' }, {}),
        (error) => assertAppError(error, 'MAINTENANCE_MODE', 503),
    );
    assert.equal(userUpdates, 0);
    assert.equal(sessionCreates, 0);
});

test('Google authentication starts no creation transaction during maintenance', async () => {
    userDelegate.findMany = (async () => []) as unknown as typeof prisma.user.findMany;
    let transactionStarted = false;
    mutablePrisma.$transaction = (async () => {
        transactionStarted = true;
    }) as unknown as typeof prisma.$transaction;

    const googleClient = {
        verifyIdToken: async () => ({
            getPayload: () => ({ email: 'new@example.com', email_verified: true, name: 'New User' }),
        }),
    };
    const service = new AuthService(
        noOpMailer as never,
        undefined,
        { assertOperational: async () => { throw maintenanceError(); } } as never,
        googleClient as never,
        'google-client-id',
    );

    await assert.rejects(
        service.authenticateGoogle({ idToken: 'valid-token' }, {}),
        (error) => assertAppError(error, 'MAINTENANCE_MODE', 503),
    );
    assert.equal(transactionStarted, false);
});

test('refresh validates the persisted session but issues no access token during maintenance', async () => {
    const password = 'UniquePass123!';
    const user = {
        ...baseUser,
        passwordHash: await hashPassword(password),
    };
    userDelegate.findMany = (async () => [user]) as unknown as typeof prisma.user.findMany;
    userDelegate.update = (async () => user) as unknown as typeof prisma.user.update;

    let persisted: { id: string; orgId: string | null; userId: string; expiresAt: Date } | undefined;
    sessionDelegate.create = (async (args: { data: typeof persisted }) => {
        persisted = args.data;
        return args.data;
    }) as unknown as typeof prisma.session.create;

    let maintenanceChecks = 0;
    const service = new AuthService(
        noOpMailer as never,
        undefined,
        {
            assertOperational: async () => {
                maintenanceChecks += 1;
                if (maintenanceChecks > 1) {
                    throw maintenanceError();
                }
            },
        } as never,
    );
    const login = await service.authenticateEmail(
        { email: user.email, password, rememberMe: false },
        {},
    );

    assert.ok(persisted);
    sessionDelegate.findFirst = (async () => persisted) as unknown as typeof prisma.session.findFirst;
    userDelegate.findUnique = (async () => user) as unknown as typeof prisma.user.findUnique;

    await assert.rejects(
        service.refreshSession(login.refreshToken),
        (error) => assertAppError(error, 'MAINTENANCE_MODE', 503),
    );
});

test('logout remains available during maintenance and revokes the supplied refresh token', async () => {
    let updateArgs: unknown;
    sessionDelegate.updateMany = (async (args: unknown) => {
        updateArgs = args;
        return { count: 1 };
    }) as unknown as typeof prisma.session.updateMany;

    const service = new AuthService(
        noOpMailer as never,
        undefined,
        { assertOperational: async () => { throw maintenanceError(); } } as never,
    );
    await service.logout('refresh-token');

    const args = updateArgs as {
        where: { refreshTokenHash: string; revokedAt: null };
        data: { revokedAt: Date };
    };
    assert.equal(typeof args.where.refreshTokenHash, 'string');
    assert.equal(args.where.refreshTokenHash.length, 64);
    assert.equal(args.where.revokedAt, null);
    assert.ok(args.data.revokedAt instanceof Date);
});
