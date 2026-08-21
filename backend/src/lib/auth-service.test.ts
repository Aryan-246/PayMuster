import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from './app-error.js';
import { AuthService } from './auth-service.js';
import { prisma } from './prisma.js';

const userDelegate = prisma.user as unknown as {
    findMany: typeof prisma.user.findMany;
};
const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const originalFindMany = userDelegate.findMany;
const originalTransaction = mutablePrisma.$transaction;

const baseUser = {
    id: '11111111-1111-4111-8111-111111111111',
    orgId: '22222222-2222-4222-8222-222222222222',
    status: 'VERIFIED',
    email: 'shared@example.com',
    firstName: 'First',
    lastName: 'User',
    provider: 'email',
    emailVerified: true,
    isActive: true,
    isDisabled: false,
    role: 'STAFF',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    passwordHash: '$2b$12$not-used-for-ambiguous-lookups',
};

const duplicateUser = {
    ...baseUser,
    id: '33333333-3333-4333-8333-333333333333',
    orgId: '44444444-4444-4444-8444-444444444444',
    createdAt: new Date('2026-02-01T00:00:00.000Z'),
    updatedAt: new Date('2026-02-01T00:00:00.000Z'),
};

function stubAmbiguousEmail(): void {
    userDelegate.findMany = (async () => [baseUser, duplicateUser]) as unknown as typeof prisma.user.findMany;
}

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
    userDelegate.findMany = originalFindMany;
    mutablePrisma.$transaction = originalTransaction;
});

test('email login fails closed when an email maps to multiple identities', async () => {
    stubAmbiguousEmail();

    await assert.rejects(
        new AuthService().authenticateEmail(
            {
                email: ' Shared@Example.com ',
                password: 'irrelevant',
                rememberMe: false,
            },
            {},
        ),
        (error) => assertAppError(error, { code: 'ACCOUNT_IDENTITY_CONFLICT', status: 409 }),
    );
});

test('email verification fails closed when an email maps to multiple identities', async () => {
    stubAmbiguousEmail();

    await assert.rejects(
        new AuthService().verifyEmail('shared@example.com', '123456'),
        (error) => assertAppError(error, { code: 'ACCOUNT_IDENTITY_CONFLICT', status: 409 }),
    );
});

test('password reset preserves anti-enumeration behavior and sends no OTP for an ambiguous email', async () => {
    stubAmbiguousEmail();

    const result = await new AuthService().requestPasswordReset('shared@example.com', {});

    assert.deepEqual(result, { accepted: true });
});

test('signup treats ambiguous existing identities as already registered and starts no transaction', async () => {
    stubAmbiguousEmail();
    let transactionStarted = false;
    mutablePrisma.$transaction = (async () => {
        transactionStarted = true;
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        new AuthService().register(
            {
                name: 'Another User',
                email: 'shared@example.com',
                password: 'UniquePass123!',
            },
            {},
        ),
        (error) => assertAppError(error, { code: 'EMAIL_ALREADY_REGISTERED', status: 409 }),
    );
    assert.equal(transactionStarted, false);
});

test('email identity lookups request at most two normalized matches', async () => {
    let lookupArgs: unknown;
    userDelegate.findMany = (async (args: unknown) => {
        lookupArgs = args;
        return [];
    }) as unknown as typeof prisma.user.findMany;

    const result = await new AuthService().resendEmailVerification('  Missing@Example.COM ');

    assert.equal(result, null);
    assert.deepEqual(
        lookupArgs,
        {
            where: {
                email: { equals: 'missing@example.com', mode: 'insensitive' },
            },
            orderBy: { createdAt: 'asc' },
            take: 2,
            select: {
                id: true,
                orgId: true,
                status: true,
                email: true,
                firstName: true,
                lastName: true,
                provider: true,
                emailVerified: true,
                isActive: true,
                isDisabled: true,
                role: true,
                createdAt: true,
                updatedAt: true,
            },
        },
    );
});

test('a unique matching account remains eligible for verification delivery', async () => {
    const unverifiedUser = {
        ...baseUser,
        emailVerified: false,
    };
    userDelegate.findMany = (async () => [unverifiedUser]) as unknown as typeof prisma.user.findMany;
    const issued = {
        id: '55555555-5555-4555-8555-555555555555',
        otp: '123456',
        expiresAt: new Date('2026-12-01T00:00:00.000Z'),
        retryAfterSeconds: 60,
    };
    const otpCalls: Array<{ userId: string; purpose: string }> = [];
    const otpManager = {
        issue: async (userId: string, purpose: string) => {
            otpCalls.push({ userId, purpose });
            return issued;
        },
        invalidate: async () => undefined,
    };
    const mailCalls: Array<{ email: string; otp: string }> = [];
    const mailer = {
        sendAccountCreatedNotification: async (email: string, data: { otp: string }) => {
            mailCalls.push({ email, otp: data.otp });
        },
    };

    const result = await new AuthService(
        mailer as never,
        otpManager as never,
    ).resendEmailVerification('shared@example.com');

    assert.equal(result, issued);
    assert.deepEqual(otpCalls, [
        { userId: unverifiedUser.id, purpose: 'email-verification' },
    ]);
    assert.deepEqual(mailCalls, [
        { email: 'shared@example.com', otp: '123456' },
    ]);
});
