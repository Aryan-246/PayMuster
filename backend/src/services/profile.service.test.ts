import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { ProfileService } from './profile.service.js';

const mutablePrisma = prisma as unknown as {
    user: { findUnique: typeof prisma.user.findUnique };
    $transaction: typeof prisma.$transaction;
};
const originalFindUnique = mutablePrisma.user.findUnique;
const originalTransaction = mutablePrisma.$transaction;

const userId = '11111111-1111-4111-8111-111111111111';
const orgId = '22222222-2222-4222-8222-222222222222';

function profileUser(overrides: Record<string, unknown> = {}) {
    return {
        id: userId,
        publicId: 'PM-USR-000001',
        email: 'profile@example.com',
        phone: '+91 9000000000',
        firstName: 'Profile',
        lastName: 'User',
        role: 'STAFF',
        status: 'VERIFIED',
        orgId,
        avatarStorageKey: null,
        org: { id: orgId, name: 'Closure Org', publicId: 'PM-ORG-000001' },
        ...overrides,
    };
}

afterEach(() => {
    mutablePrisma.user.findUnique = originalFindUnique;
    mutablePrisma.$transaction = originalTransaction;
});

test('profile update persists only supported fields and writes before/after audit values', async () => {
    const calls: Array<{ operation: string; args: any }> = [];
    mutablePrisma.user.findUnique = (async () => profileUser()) as any;
    const transactionClient = {
        user: {
            update: async (args: unknown) => {
                calls.push({ operation: 'user.update', args });
                return profileUser({ firstName: 'Updated', lastName: 'Name', phone: '+91 9111111111' });
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
        staffDocument: { findMany: async () => [] },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as any;

    const result = await new ProfileService({
        upload: async () => undefined,
        remove: async () => undefined,
        createSignedViewUrl: async () => ({ url: 'https://signed.example/avatar', expiresInSeconds: 300 }),
    } as any).updateProfile(userId, { name: 'Updated Name', phone: '+91 9111111111' });

    assert.equal(result.name, 'Updated Name');
    assert.deepEqual(calls.map((call) => call.operation), ['user.update', 'auditLog.create']);
    assert.deepEqual(calls[0].args.data, {
        firstName: 'Updated',
        lastName: 'Name',
        phone: '+91 9111111111',
    });
    assert.equal(calls[1].args.data.entityType, 'UserProfile');
    assert.deepEqual(calls[1].args.data.beforeValue, {
        firstName: 'Profile',
        lastName: 'User',
        phone: '+91 9000000000',
    });
});

test('profile update rejects invalid phone before starting a transaction', async () => {
    let transactionCalls = 0;
    mutablePrisma.user.findUnique = (async () => profileUser()) as any;
    mutablePrisma.$transaction = (async () => {
        transactionCalls += 1;
        return undefined;
    }) as any;

    await assert.rejects(
        new ProfileService().updateProfile(userId, { name: 'Valid Name', phone: 'not-a-phone' }),
        (error) => {
            assert.ok(error instanceof AppError);
            assert.equal(error.code, 'PROFILE_PHONE_INVALID');
            assert.equal(error.status, 400);
            return true;
        },
    );
    assert.equal(transactionCalls, 0);
});

test('avatar upload compensates the new private object when database persistence fails', async () => {
    const uploaded: string[] = [];
    const removed: string[] = [];
    mutablePrisma.user.findUnique = (async () => profileUser()) as any;
    mutablePrisma.$transaction = (async () => {
        throw new Error('simulated profile persistence failure');
    }) as any;

    const service = new ProfileService({
        upload: async (key: string) => uploaded.push(key),
        remove: async (key: string) => removed.push(key),
        createSignedViewUrl: async () => ({ url: 'https://signed.example/avatar', expiresInSeconds: 300 }),
    } as any);

    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    await assert.rejects(service.uploadAvatar(userId, { mimeType: 'image/png', body: png }));
    assert.equal(uploaded.length, 1);
    assert.deepEqual(removed, uploaded);
    assert.match(uploaded[0], new RegExp(`^avatars/${userId}/[a-f0-9-]+\\.png$`));
});

test('avatar upload rejects a mismatched image signature before storage access', async () => {
    let uploads = 0;
    const service = new ProfileService({
        upload: async () => { uploads += 1; },
        remove: async () => undefined,
        createSignedViewUrl: async () => ({ url: 'https://signed.example/avatar', expiresInSeconds: 300 }),
    } as any);

    await assert.rejects(
        service.uploadAvatar(userId, { mimeType: 'image/png', body: Buffer.from('not-png') }),
        (error) => {
            assert.ok(error instanceof AppError);
            assert.equal(error.code, 'AVATAR_CONTENT_INVALID');
            return true;
        },
    );
    assert.equal(uploads, 0);
});
