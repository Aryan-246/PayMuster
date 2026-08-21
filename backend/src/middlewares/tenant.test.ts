import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import { prisma } from '../lib/prisma.js';
import { requireTenant } from './tenant.middleware.js';

const siteDelegate = prisma.site as unknown as {
    findUnique: typeof prisma.site.findUnique;
};
const originalFindUnique = siteDelegate.findUnique;

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
