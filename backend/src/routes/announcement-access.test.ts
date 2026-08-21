import assert from 'node:assert/strict';
import test from 'node:test';
import type { NextFunction, Request, Response } from 'express';

import adminRouter from './admin.routes.js';
import announcementRouter from './announcement.routes.js';

interface RouteHandler {
    name?: string;
    handle: (req: Request, res: Response, next: NextFunction) => unknown;
}

interface RouterLayer {
    name: string;
    route?: {
        path: string;
        methods: Record<string, boolean>;
        stack: RouteHandler[];
    };
}

function layers(router: unknown): RouterLayer[] {
    return (router as { stack: RouterLayer[] }).stack;
}

function routeLayer(router: unknown, path: string): RouterLayer {
    const layer = layers(router).find((candidate) => candidate.route?.path === path);
    assert.ok(layer, `Expected route ${path}`);
    return layer;
}

test('recipient announcement routes are mounted only after authentication', () => {
    const routerLayers = layers(announcementRouter);
    const requireAuthIndex = routerLayers.findIndex((layer) => layer.name === 'requireAuth');
    const listIndex = routerLayers.findIndex((layer) => layer.route?.path === '/');
    const streamIndex = routerLayers.findIndex((layer) => layer.route?.path === '/stream');
    const acknowledgeIndex = routerLayers.findIndex(
        (layer) => layer.route?.path === '/:id/acknowledge',
    );

    assert.ok(requireAuthIndex >= 0);
    assert.ok(listIndex > requireAuthIndex);
    assert.ok(streamIndex > requireAuthIndex);
    assert.ok(acknowledgeIndex > requireAuthIndex);
    assert.equal(routerLayers[listIndex].route!.methods.get, true);
    assert.equal(routerLayers[streamIndex].route!.methods.get, true);
    assert.equal(routerLayers[acknowledgeIndex].route!.methods.post, true);
});

test('acknowledgement route rejects malformed notification IDs before its controller', async () => {
    const acknowledgeRoute = routeLayer(announcementRouter, '/:id/acknowledge').route!;
    assert.ok(acknowledgeRoute.stack.length >= 3);

    const validationHandler = acknowledgeRoute.stack[0].handle;
    const request = { params: { id: 'not-a-uuid' } } as unknown as Request;
    const capture: { status?: number; body?: unknown; nextCalled: boolean } = {
        nextCalled: false,
    };
    const response = {
        locals: {},
        status(code: number) {
            capture.status = code;
            return this;
        },
        json(body: unknown) {
            capture.body = body;
            return this;
        },
    } as unknown as Response;
    const next = (() => {
        capture.nextCalled = true;
    }) as NextFunction;

    await validationHandler(request, response, next);

    assert.equal(capture.nextCalled, false);
    assert.equal(capture.status, 400);
    const body = capture.body as {
        success: boolean;
        error: { code: string; details: Array<{ path: PropertyKey[] }> };
    };
    assert.equal(body.success, false);
    assert.equal(body.error.code, 'VALIDATION_ERROR');
    assert.equal(
        body.error.details.some((detail) =>
            detail.path.length === 1 && detail.path[0] === 'id'),
        true,
    );
});

test('Admin announcement dispatch exists only after authentication and manage-system permission gates', () => {
    const routerLayers = layers(adminRouter);
    const dispatchIndex = routerLayers.findIndex(
        (layer) => layer.route?.path === '/announcements',
    );
    const requireAuthIndex = routerLayers.findIndex((layer) => layer.name === 'requireAuth');
    const permissionIndex = routerLayers.findIndex(
        (layer, index) => index > requireAuthIndex && !layer.route,
    );

    assert.ok(dispatchIndex >= 0);
    assert.ok(requireAuthIndex >= 0 && requireAuthIndex < dispatchIndex);
    assert.ok(permissionIndex > requireAuthIndex && permissionIndex < dispatchIndex);

    const dispatchRoute = routerLayers[dispatchIndex].route!;
    assert.equal(dispatchRoute.methods.post, true);
    assert.equal(dispatchRoute.methods.get, undefined);
    assert.equal(
        layers(announcementRouter).some((layer) => layer.route?.path === '/announcements'),
        false,
    );
});
