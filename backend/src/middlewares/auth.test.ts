import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import { authService } from '../lib/auth-service.js';
import { maintenanceService } from '../lib/maintenance-service.js';
import { prisma } from '../lib/prisma.js';
import { requireAuth } from './auth.js';

const userDelegate = prisma.user as unknown as {
    findUnique: typeof prisma.user.findUnique;
};
const sessionDelegate = prisma.session as unknown as {
    findFirst: typeof prisma.session.findFirst;
};
const mutableAuthService = authService as unknown as {
    verifyAccessToken: typeof authService.verifyAccessToken;
};
const mutableMaintenance = maintenanceService as unknown as {
    assertOperational: typeof maintenanceService.assertOperational;
};

const originals = {
    userFindUnique: userDelegate.findUnique,
    sessionFindFirst: sessionDelegate.findFirst,
    verifyAccessToken: mutableAuthService.verifyAccessToken,
    assertOperational: mutableMaintenance.assertOperational,
};

const user = {
    id: '11111111-1111-4111-8111-111111111111',
    orgId: '22222222-2222-4222-8222-222222222222',
    email: 'person@example.com',
    role: 'OWNER',
    status: 'VERIFIED',
    isActive: true,
    isDisabled: false,
};
const session = {
    id: '33333333-3333-4333-8333-333333333333',
    orgId: user.orgId,
};

interface ResponseCapture {
    statusCode?: number;
    body?: unknown;
}

function requestStub(): Request {
    return {
        id: 'request-id',
        headers: { authorization: 'Bearer access-token' },
    } as Request;
}

function responseStub(capture: ResponseCapture): Response {
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

function tokenClaims(overrides: Partial<ReturnType<typeof authService.verifyAccessToken>> = {}) {
    return {
        userId: user.id,
        orgId: user.orgId,
        role: 'STAFF',
        sessionId: session.id,
        ...overrides,
    };
}

afterEach(() => {
    userDelegate.findUnique = originals.userFindUnique;
    sessionDelegate.findFirst = originals.sessionFindFirst;
    mutableAuthService.verifyAccessToken = originals.verifyAccessToken;
    mutableMaintenance.assertOperational = originals.assertOperational;
});

test('requireAuth rejects a revoked or expired session immediately', async () => {
    mutableAuthService.verifyAccessToken = (() => tokenClaims()) as typeof authService.verifyAccessToken;
    userDelegate.findUnique = (async () => user) as unknown as typeof prisma.user.findUnique;
    sessionDelegate.findFirst = (async () => null) as unknown as typeof prisma.session.findFirst;
    mutableMaintenance.assertOperational = (async () => undefined) as typeof maintenanceService.assertOperational;

    const capture: ResponseCapture = {};
    let nextCalls = 0;
    await requireAuth(
        requestStub(),
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 401);
    assert.deepEqual(capture.body, {
        success: false,
        error: {
            code: 'SESSION_INVALID',
            message: 'Your session is invalid. Please sign in again.',
        },
    });
});

test('requireAuth rejects a session whose organization differs from the access token', async () => {
    mutableAuthService.verifyAccessToken = (() => tokenClaims({
        orgId: '44444444-4444-4444-8444-444444444444',
    })) as typeof authService.verifyAccessToken;
    userDelegate.findUnique = (async () => user) as unknown as typeof prisma.user.findUnique;
    sessionDelegate.findFirst = (async () => session) as unknown as typeof prisma.session.findFirst;
    mutableMaintenance.assertOperational = (async () => undefined) as typeof maintenanceService.assertOperational;

    const capture: ResponseCapture = {};
    let nextCalls = 0;
    await requireAuth(
        requestStub(),
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 401);
    assert.equal(
        (capture.body as { error: { code: string } }).error.code,
        'SESSION_INVALID',
    );
});

test('requireAuth rejects a user moved to a different organization after session issuance', async () => {
    mutableAuthService.verifyAccessToken = (() => tokenClaims()) as typeof authService.verifyAccessToken;
    userDelegate.findUnique = (async () => ({
        ...user,
        orgId: '55555555-5555-4555-8555-555555555555',
    })) as unknown as typeof prisma.user.findUnique;
    sessionDelegate.findFirst = (async () => session) as unknown as typeof prisma.session.findFirst;
    mutableMaintenance.assertOperational = (async () => undefined) as typeof maintenanceService.assertOperational;

    const capture: ResponseCapture = {};
    let nextCalls = 0;
    await requireAuth(
        requestStub(),
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 401);
    assert.equal(
        (capture.body as { error: { code: string } }).error.code,
        'SESSION_INVALID',
    );
});

test('requireAuth accepts a matching active session and installs current database authorization', async () => {
    mutableAuthService.verifyAccessToken = (() => tokenClaims()) as typeof authService.verifyAccessToken;
    userDelegate.findUnique = (async () => user) as unknown as typeof prisma.user.findUnique;
    sessionDelegate.findFirst = (async () => session) as unknown as typeof prisma.session.findFirst;
    const checkedRoles: string[] = [];
    mutableMaintenance.assertOperational = (async (role?: string) => {
        if (role) checkedRoles.push(role);
    }) as typeof maintenanceService.assertOperational;

    const request = requestStub();
    const capture: ResponseCapture = {};
    let nextCalls = 0;
    await requireAuth(
        request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 1);
    assert.equal(capture.statusCode, undefined);
    assert.deepEqual(checkedRoles, ['OWNER']);
    assert.deepEqual(request.context?.user, {
        id: user.id,
        email: user.email,
        role: 'OWNER',
        orgId: user.orgId,
    });
    assert.deepEqual((request as Request & { user?: unknown }).user, {
        userId: user.id,
        orgId: user.orgId,
        role: 'OWNER',
    });
});
