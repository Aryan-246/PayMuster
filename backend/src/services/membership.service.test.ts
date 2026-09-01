import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { prisma } from '../lib/prisma.js';
import { membershipService } from './membership.service.js';
import { featureFlags, resetFeatureFlags } from '../lib/feature-flags.js';

const userDelegate = prisma.user as unknown as {
    findUnique: typeof prisma.user.findUnique;
};
const membershipDelegate = prisma.membership as unknown as {
    findMany: typeof prisma.membership.findMany;
};
const originalUserFindUnique = userDelegate.findUnique;
const originalMembershipFindMany = membershipDelegate.findMany;

afterEach(() => {
    userDelegate.findUnique = originalUserFindUnique;
    membershipDelegate.findMany = originalMembershipFindMany;
    resetFeatureFlags();
});

test('Flag OFF: only the primary org is returned and memberships are never queried', async () => {
    featureFlags.multiCompanyEnabled = false;
    let membershipQueries = 0;
    userDelegate.findUnique = (async () => ({
        orgId: 'org-1',
        org: { id: 'org-1', name: 'Primary Co', publicId: 'PRI' },
    })) as unknown as typeof prisma.user.findUnique;
    membershipDelegate.findMany = (async () => {
        membershipQueries += 1;
        return [];
    }) as unknown as typeof prisma.membership.findMany;

    const result = await membershipService.listUserCompanies('user-1');

    assert.deepEqual(result, {
        multiCompanyEnabled: false,
        primary: { orgId: 'org-1', name: 'Primary Co', publicId: 'PRI' },
        memberships: [],
    });
    assert.equal(membershipQueries, 0, 'flag OFF must not read memberships');
});

test('Flag ON: ACTIVE memberships are listed, excluding the primary org', async () => {
    featureFlags.multiCompanyEnabled = true;
    userDelegate.findUnique = (async () => ({
        orgId: 'org-1',
        org: { id: 'org-1', name: 'Primary Co', publicId: 'PRI' },
    })) as unknown as typeof prisma.user.findUnique;
    membershipDelegate.findMany = (async () => [
        { orgId: 'org-2', role: 'OWNER', status: 'ACTIVE', org: { id: 'org-2', name: 'Second Co', publicId: 'SEC' } },
        { orgId: 'org-1', role: 'ADMIN', status: 'ACTIVE', org: { id: 'org-1', name: 'Primary Co', publicId: 'PRI' } },
    ]) as unknown as typeof prisma.membership.findMany;

    const result = await membershipService.listUserCompanies('user-1');

    assert.equal(result.multiCompanyEnabled, true);
    assert.deepEqual(result.primary, { orgId: 'org-1', name: 'Primary Co', publicId: 'PRI' });
    assert.equal(result.memberships.length, 1, 'the primary org must not appear as a switch target');
    assert.deepEqual(result.memberships[0], {
        orgId: 'org-2',
        name: 'Second Co',
        publicId: 'SEC',
        role: 'OWNER',
        status: 'ACTIVE',
    });
});

test('Flag ON: a user without a primary org still lists memberships honestly', async () => {
    featureFlags.multiCompanyEnabled = true;
    userDelegate.findUnique = (async () => ({ orgId: null, org: null })) as unknown as typeof prisma.user.findUnique;
    membershipDelegate.findMany = (async () => [
        { orgId: 'org-2', role: 'ADMIN', status: 'ACTIVE', org: { id: 'org-2', name: 'Second Co', publicId: 'SEC' } },
    ]) as unknown as typeof prisma.membership.findMany;

    const result = await membershipService.listUserCompanies('user-1');

    assert.equal(result.primary, null);
    assert.equal(result.memberships.length, 1);
    assert.equal(result.memberships[0].orgId, 'org-2');
});

test('Unknown user: honest empty response, never a fabricated primary', async () => {
    featureFlags.multiCompanyEnabled = true;
    userDelegate.findUnique = (async () => null) as unknown as typeof prisma.user.findUnique;
    membershipDelegate.findMany = (async () => []) as unknown as typeof prisma.membership.findMany;

    const result = await membershipService.listUserCompanies('ghost');

    assert.equal(result.primary, null);
    assert.deepEqual(result.memberships, []);
});
