import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import { prisma } from '../lib/prisma.js';
import { requireTenant } from './tenant.middleware.js';
import { featureFlags, resetFeatureFlags } from '../lib/feature-flags.js';

const siteDelegate = prisma.site as unknown as {
    findUnique: typeof prisma.site.findUnique;
};
const originalFindUnique = siteDelegate.findUnique;
const membershipDelegate = prisma.membership as unknown as {
    findFirst: typeof prisma.membership.findFirst;
};
const originalMembershipFindFirst = membershipDelegate.findFirst;

interface Capture {
    statusCode?: number;
    body?: unknown;
}

function responseStub(capture: Capture): Response {
    const response = {
        status(code: number) {
            capture.statusCode = code;
            return response;
        },
        json(body: unknown) {
            capture.body = body;
            return response;
        },
    };
    return response as unknown as Response;
}

function requestStub(overrides: Partial<Request> = {}): Request {
    return {
        params: {},
        headers: {},
        context: {
            requestId: 'tenant-test',
            user: {
                id: 'user-id',
                email: 'staff@example.com',
                role: 'STAFF',
                orgId: 'org-id',
            },
        },
        ...overrides,
    } as Request;
}

afterEach(() => {
    siteDelegate.findUnique = originalFindUnique;
    membershipDelegate.findFirst = originalMembershipFindFirst;
    resetFeatureFlags();
});

test('Site tenant middleware derives company context from the verified Site row', async () => {
    siteDelegate.findUnique = (async () => ({ id: 'site-id', orgId: 'org-id' })) as unknown as typeof prisma.site.findUnique;
    const request = requestStub({ params: { siteId: 'site-id' } });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'SITE' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 1);
    assert.equal(capture.statusCode, undefined);
    assert.deepEqual(request.context.tenant, { companyId: 'org-id', siteId: 'site-id' });
});

test('Site tenant middleware rejects a company header that conflicts with the Site owner', async () => {
    siteDelegate.findUnique = (async () => ({ id: 'site-id', orgId: 'other-org' })) as unknown as typeof prisma.site.findUnique;
    const request = requestStub({
        params: { siteId: 'site-id' },
        headers: { 'x-company-id': 'org-id' },
    });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'SITE' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 403);
    assert.equal((capture.body as { error: { code: string } }).error.code, 'TENANT_FORBIDDEN');
});

// ---------------------------------------------------------------------
// Multi-company membership mode (blueprint §L) — flag-gated tenant access.
// ---------------------------------------------------------------------

test('Multi-company flag OFF ignores membership rows entirely — unaffiliated company stays forbidden', async () => {
    featureFlags.multiCompanyEnabled = false;
    let membershipQueries = 0;
    membershipDelegate.findFirst = (async () => {
        membershipQueries += 1;
        return { id: 'membership-id' };
    }) as unknown as typeof prisma.membership.findFirst;

    const request = requestStub({ headers: { 'x-company-id': 'other-org' } });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'COMPANY' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 403);
    assert.equal((capture.body as { error: { code: string } }).error.code, 'TENANT_FORBIDDEN');
    assert.equal(membershipQueries, 0, 'flag OFF must never read the memberships table');
});

test('Multi-company flag ON grants tenant access through an ACTIVE membership', async () => {
    featureFlags.multiCompanyEnabled = true;
    membershipDelegate.findFirst = (async () => ({ id: 'membership-id' })) as unknown as typeof prisma.membership.findFirst;

    const request = requestStub({ headers: { 'x-company-id': 'other-org' } });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'COMPANY' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 1);
    assert.equal(capture.statusCode, undefined);
    assert.deepEqual(request.context.tenant, { companyId: 'other-org', siteId: undefined });
});

test('Multi-company flag ON still denies when no ACTIVE membership exists', async () => {
    featureFlags.multiCompanyEnabled = true;
    membershipDelegate.findFirst = (async () => null) as unknown as typeof prisma.membership.findFirst;

    const request = requestStub({ headers: { 'x-company-id': 'other-org' } });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'COMPANY' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 403);
    assert.equal((capture.body as { error: { code: string } }).error.code, 'TENANT_FORBIDDEN');
});

test('Multi-company flag ON keeps the primary-org path working without consulting memberships', async () => {
    featureFlags.multiCompanyEnabled = true;
    let membershipQueries = 0;
    membershipDelegate.findFirst = (async () => {
        membershipQueries += 1;
        return null;
    }) as unknown as typeof prisma.membership.findFirst;

    const request = requestStub({ headers: { 'x-company-id': 'org-id' } });
    const capture: Capture = {};
    let nextCalls = 0;

    await requireTenant({ scope: 'COMPANY' })(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 1);
    assert.equal(capture.statusCode, undefined);
    assert.equal(membershipQueries, 0, 'primary-org access must not need a membership lookup');
});
