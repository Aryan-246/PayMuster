import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { maintenanceService } from '../lib/maintenance-service.js';
import router, { requirePublicOperationalState } from './auth.js';

const mutableMaintenance = maintenanceService as unknown as {
    assertOperational: typeof maintenanceService.assertOperational;
};
const originalAssertOperational = mutableMaintenance.assertOperational;

interface ResponseCapture {
    statusCode?: number;
    body?: unknown;
}

function responseStub(capture: ResponseCapture): Response {
    const response = {
        setHeader() {
            return response;
        },
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

afterEach(() => {
    mutableMaintenance.assertOperational = originalAssertOperational;
});

test('public maintenance gate returns the standard typed maintenance response', async () => {
    mutableMaintenance.assertOperational = (async () => {
        throw new AppError(
            'MAINTENANCE_MODE',
            'PayMuster is temporarily unavailable for maintenance.',
            503,
        );
    }) as typeof maintenanceService.assertOperational;

    const capture: ResponseCapture = {};
    let nextCalls = 0;
    await requirePublicOperationalState(
        { method: 'POST', path: '/signup', ip: '127.0.0.1' } as Request,
        responseStub(capture),
        (() => { nextCalls += 1; }) as NextFunction,
    );

    assert.equal(nextCalls, 0);
    assert.equal(capture.statusCode, 503);
    assert.deepEqual(capture.body, {
        error: {
            code: 'MAINTENANCE_MODE',
            message: 'PayMuster is temporarily unavailable for maintenance.',
            retryAfterSeconds: undefined,
        },
    });
});

test('public identity mutations are gated while role-aware session routes and logout are not', () => {
    type RouterLayer = {
        route?: {
            path: string;
            stack: Array<{ handle: { name?: string } }>;
        };
    };
    const layers = (router as unknown as { stack: RouterLayer[] }).stack;
    const middlewareNames = new Map(
        layers
            .filter((layer) => layer.route)
            .map((layer) => [
                layer.route!.path,
                layer.route!.stack.map((entry) => entry.handle.name),
            ]),
    );

    for (const path of [
        '/signup',
        '/resend-verification',
        '/verify-email',
        '/verify-otp',
        '/forgot-password',
        '/reset-password',
    ]) {
        assert.ok(
            middlewareNames.get(path)?.includes('requirePublicOperationalState'),
            `${path} must be blocked during maintenance`,
        );
    }

    for (const path of ['/login', '/google', '/refresh', '/logout']) {
        assert.equal(
            middlewareNames.get(path)?.includes('requirePublicOperationalState'),
            false,
            `${path} must not use the role-blind public maintenance gate`,
        );
    }
});
