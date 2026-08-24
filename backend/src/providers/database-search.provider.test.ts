import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { prisma } from '../lib/prisma.js';
import { DatabaseSearchProvider } from './database-search.provider.js';

const userDelegate = prisma.user as unknown as {
    findMany: typeof prisma.user.findMany;
    count: typeof prisma.user.count;
};
const originalFindMany = userDelegate.findMany;
const originalCount = userDelegate.count;

const context = {
    userId: '11111111-1111-4111-8111-111111111111',
    role: 'STAFF',
    orgId: '22222222-2222-4222-8222-222222222222',
    permissions: ['view_staff'] as const,
};

afterEach(() => {
    userDelegate.findMany = originalFindMany;
    userDelegate.count = originalCount;
});

test('database search applies tenant and query filters before returning user hits', async () => {
    let findWhere: Record<string, unknown> | undefined;
    let countWhere: Record<string, unknown> | undefined;
    userDelegate.findMany = (async (args: any) => {
        findWhere = args.where;
        return [{
            id: '33333333-3333-4333-8333-333333333333',
            publicId: 'PM-USR-000001',
            email: 'worker@example.com',
            firstName: 'Worker',
            lastName: 'One',
            role: 'STAFF',
            status: 'VERIFIED',
            orgId: context.orgId,
        }];
    }) as any;
    userDelegate.count = (async (args: any) => {
        countWhere = args.where;
        return 1;
    }) as any;

    const result = await new DatabaseSearchProvider().search({
        query: 'worker',
        page: 1,
        limit: 50,
        filters: { role: 'STAFF', status: 'ACTIVE' },
        context,
    });

    assert.equal(result.total, 1);
    assert.equal(result.fallbackUsed, true);
    assert.equal(result.provider, 'database');
    assert.equal(result.hits[0].entityType, 'USER');
    assert.equal(result.hits[0].orgId, context.orgId);
    assert.equal(findWhere?.orgId, context.orgId);
    assert.deepEqual(findWhere?.role, 'STAFF');
    assert.equal(findWhere?.isActive, true);
    assert.equal(findWhere?.isDisabled, false);
    assert.deepEqual(countWhere, findWhere);
});

test('database search does not add a tenant predicate for Super Admin', async () => {
    let findWhere: Record<string, unknown> | undefined;
    userDelegate.findMany = (async (args: any) => {
        findWhere = args.where;
        return [];
    }) as any;
    userDelegate.count = (async () => 0) as any;

    await new DatabaseSearchProvider().search({
        query: '',
        page: 1,
        limit: 20,
        filters: {},
        context: { ...context, role: 'SUPER_ADMIN', orgId: null },
    });

    assert.equal('orgId' in (findWhere ?? {}), false);
    assert.equal(findWhere?.deletedAt, null);
});

test('database search bounds page size and never returns a navigation route', async () => {
    userDelegate.findMany = (async () => [{
        id: '33333333-3333-4333-8333-333333333333',
        publicId: null,
        email: null,
        firstName: null,
        lastName: null,
        role: 'STAFF',
        status: 'PENDING',
        orgId: context.orgId,
    }]) as any;
    userDelegate.count = (async () => 1) as any;

    const result = await new DatabaseSearchProvider().search({
        query: 'x',
        page: 1,
        limit: 1000,
        filters: {},
        context,
    });

    assert.equal(result.hits[0].route, undefined);
    assert.equal(result.totalPages, 1);
});
