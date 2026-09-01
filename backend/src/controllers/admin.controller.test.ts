import assert from 'node:assert/strict';
import test, { afterEach, beforeEach } from 'node:test';
import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { adminController } from './admin.controller.js';
import { subscriptionService } from '../services/subscription.service.js';

const orgId = '11111111-1111-4111-8111-111111111111';

type Captured = { status?: number; body?: unknown };

function fakeRes(): { res: Response; captured: Captured } {
    const captured: Captured = {};
    const res = {
        status(code: number) {
            captured.status = code;
            return res;
        },
        json(body: unknown) {
            captured.body = body;
            return res;
        },
    } as unknown as Response;
    return { res, captured };
}

function fakeReq(overrides: Partial<{ user: unknown; body: unknown; params: unknown }> = {}): Request {
    return {
        id: 'req-test',
        context: 'user' in overrides ? { requestId: 'req-test', user: overrides.user } : { requestId: 'req-test' },
        body: overrides.body ?? {},
        params: overrides.params ?? {},
    } as unknown as Request;
}

const superAdmin = { id: 'sa-1', email: 'sa@paymuster.com', role: 'SUPER_ADMIN', orgId: null };

const grantDelegate = subscriptionService as unknown as {
    grantUnlimitedAccess: typeof subscriptionService.grantUnlimitedAccess;
    revokeUnlimitedAccess: typeof subscriptionService.revokeUnlimitedAccess;
    getGlobalSubscriptionSwitch: typeof subscriptionService.getGlobalSubscriptionSwitch;
    setGlobalSubscriptionSwitch: typeof subscriptionService.setGlobalSubscriptionSwitch;
};
const originalGrant = grantDelegate.grantUnlimitedAccess;
const originalRevoke = grantDelegate.revokeUnlimitedAccess;
const originalGetSwitch = grantDelegate.getGlobalSubscriptionSwitch;
const originalSetSwitch = grantDelegate.setGlobalSubscriptionSwitch;

afterEach(() => {
    grantDelegate.grantUnlimitedAccess = originalGrant;
    grantDelegate.revokeUnlimitedAccess = originalRevoke;
    // Restore the persisted-switch delegates so a stub cannot leak into other tests.
    grantDelegate.getGlobalSubscriptionSwitch = originalGetSwitch;
    grantDelegate.setGlobalSubscriptionSwitch = originalSetSwitch;
});

test('getSubscriptionSwitch reports the current server-authoritative switch state', async () => {
    grantDelegate.getGlobalSubscriptionSwitch = (async () => true) as typeof subscriptionService.getGlobalSubscriptionSwitch;
    const { res, captured } = fakeRes();

    await adminController.getSubscriptionSwitch(fakeReq({ user: superAdmin }), res);

    assert.equal(captured.status, 200);
    assert.deepEqual(captured.body, {
        success: true,
        data: { enabled: true },
        meta: { requestId: 'req-test' },
    });
});

test('setSubscriptionSwitch toggles enforcement OFF and returns the new state', async () => {
    let received: { enabled: boolean; actorId: string; actorRole: string } | undefined;
    grantDelegate.setGlobalSubscriptionSwitch = (async (enabled: boolean, actorId: string, actorRole: string) => {
        received = { enabled, actorId, actorRole };
        return enabled;
    }) as typeof subscriptionService.setGlobalSubscriptionSwitch;
    const { res, captured } = fakeRes();

    await adminController.setSubscriptionSwitch(
        fakeReq({ user: superAdmin, body: { enabled: false } }),
        res,
    );

    assert.equal(captured.status, 200);
    assert.deepEqual((captured.body as { data: unknown }).data, { enabled: false });
    // The controller forwards the actor identity and role to the persisted switch.
    assert.deepEqual(received, { enabled: false, actorId: 'sa-1', actorRole: 'SUPER_ADMIN' });
});

test('setSubscriptionSwitch rejects a non-boolean payload before mutating state', async () => {
    let serviceCalled = false;
    grantDelegate.setGlobalSubscriptionSwitch = (async () => {
        serviceCalled = true;
        return true;
    }) as typeof subscriptionService.setGlobalSubscriptionSwitch;
    const { res } = fakeRes();

    await assert.rejects(
        adminController.setSubscriptionSwitch(
            fakeReq({ user: superAdmin, body: { enabled: 'yes' } }),
            res,
        ),
        (error) => error instanceof AppError && error.code === 'VALIDATION_ERROR' && error.status === 400,
    );
    // State is untouched by the rejected request: the service is never invoked.
    assert.equal(serviceCalled, false);
});

test('setSubscriptionSwitch answers 401 when no authenticated actor is present', async () => {
    let serviceCalled = false;
    grantDelegate.setGlobalSubscriptionSwitch = (async () => {
        serviceCalled = true;
        return true;
    }) as typeof subscriptionService.setGlobalSubscriptionSwitch;
    const { res, captured } = fakeRes();

    await adminController.setSubscriptionSwitch(fakeReq({ body: { enabled: false } }), res);

    assert.equal(captured.status, 401);
    assert.equal((captured.body as { error: { code: string } }).error.code, 'UNAUTHORIZED');
    assert.equal(serviceCalled, false);
});

test('grantUnlimitedAccess delegates to the service with the actor identity and role', async () => {
    let received: { orgId: string; actorId: string; actorRole: string } | undefined;
    grantDelegate.grantUnlimitedAccess = (async (org: string, actorId: string, actorRole: string) => {
        received = { orgId: org, actorId, actorRole };
        return { id: 'sub-1', unlimitedAccess: true } as never;
    }) as typeof subscriptionService.grantUnlimitedAccess;
    const { res, captured } = fakeRes();

    await adminController.grantUnlimitedAccess(
        fakeReq({ user: superAdmin, params: { orgId } }),
        res,
    );

    assert.deepEqual(received, { orgId, actorId: 'sa-1', actorRole: 'SUPER_ADMIN' });
    assert.equal(captured.status, 200);
    assert.deepEqual((captured.body as { data: unknown }).data, {
        orgId,
        subscriptionId: 'sub-1',
        unlimitedAccess: true,
    });
});

test('revokeUnlimitedAccess delegates to the service and reports the restored state', async () => {
    let received: { orgId: string; actorId: string; actorRole: string } | undefined;
    grantDelegate.revokeUnlimitedAccess = (async (org: string, actorId: string, actorRole: string) => {
        received = { orgId: org, actorId, actorRole };
        return { id: 'sub-1', unlimitedAccess: false } as never;
    }) as typeof subscriptionService.revokeUnlimitedAccess;
    const { res, captured } = fakeRes();

    await adminController.revokeUnlimitedAccess(
        fakeReq({ user: superAdmin, params: { orgId } }),
        res,
    );

    assert.deepEqual(received, { orgId, actorId: 'sa-1', actorRole: 'SUPER_ADMIN' });
    assert.equal(captured.status, 200);
    assert.deepEqual((captured.body as { data: unknown }).data, {
        orgId,
        subscriptionId: 'sub-1',
        unlimitedAccess: false,
    });
});

test('grantUnlimitedAccess answers 401 when no authenticated actor is present', async () => {
    let serviceCalled = false;
    grantDelegate.grantUnlimitedAccess = (async () => {
        serviceCalled = true;
        return {} as never;
    }) as typeof subscriptionService.grantUnlimitedAccess;
    const { res, captured } = fakeRes();

    await adminController.grantUnlimitedAccess(fakeReq({ params: { orgId } }), res);

    assert.equal(captured.status, 401);
    assert.equal((captured.body as { error: { code: string } }).error.code, 'UNAUTHORIZED');
    assert.equal(serviceCalled, false);
});
