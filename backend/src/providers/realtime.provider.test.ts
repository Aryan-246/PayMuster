import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { prisma } from '../lib/prisma.js';
import { existingRealtimeProvider } from './realtime.provider.js';

const siteDelegate = prisma.site as unknown as { findFirst: typeof prisma.site.findFirst };
const userDelegate = prisma.user as unknown as { count: typeof prisma.user.count };
const originalSiteFindFirst = siteDelegate.findFirst;
const originalUserCount = userDelegate.count;

afterEach(() => {
    siteDelegate.findFirst = originalSiteFindFirst;
    userDelegate.count = originalUserCount;
});

test('existing realtime provider rejects cross-tenant or non-member channel access', async () => {
    const provider = existingRealtimeProvider;
    assert.equal(await provider.authorize({
        channelId: 'org-channel',
        orgId: 'other-org',
        memberIds: ['user-1'],
        context: { userId: 'user-1', role: 'STAFF', orgId: 'org-1', permissions: ['chat.view'] },
    }), false);
    assert.equal(await provider.authorize({
        channelId: 'org-channel',
        orgId: 'org-1',
        memberIds: ['user-2'],
        context: { userId: 'user-1', role: 'STAFF', orgId: 'org-1', permissions: ['chat.view'] },
    }), false);
});

test('existing realtime provider verifies site ownership and active members', async () => {
    siteDelegate.findFirst = (async () => ({ id: 'site-1' })) as any;
    userDelegate.count = (async () => 2) as any;
    assert.equal(await existingRealtimeProvider.authorize({
        channelId: 'site-channel',
        orgId: 'org-1',
        siteId: 'site-1',
        memberIds: ['user-1', 'user-2'],
        context: { userId: 'user-1', role: 'STAFF', orgId: 'org-1', siteId: 'site-1', permissions: ['chat.view'] },
    }), true);
});
