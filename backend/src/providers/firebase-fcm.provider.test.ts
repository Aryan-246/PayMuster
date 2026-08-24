import assert from 'node:assert/strict';
import test from 'node:test';

import { FirebaseFcmProvider } from './firebase-fcm.provider.js';

const token = 'fcm-token-that-is-long-enough-for-tests-123456789';
const baseOptions = {
    enabled: true,
    projectId: 'paymuster-test',
    clientEmail: 'firebase@example.test',
    privateKey: '-----BEGIN PRIVATE KEY-----\\nprivate\\n-----END PRIVATE KEY-----',
    accessTokenProvider: async () => 'test-access-token',
    timeoutMs: 50,
    sleep: async () => undefined,
};

function message() {
    return {
        eventId: 'delivery-id',
        token,
        title: 'Shift assigned',
        body: 'You were assigned to a site.',
        data: { notification_id: 'notification-id', deep_link: '/app/sites' },
    };
}

test('FCM remains unavailable without enabled configuration and does not call the transport', async () => {
    let calls = 0;
    const provider = new FirebaseFcmProvider({
        ...baseOptions,
        enabled: false,
        httpClient: async () => {
            calls += 1;
            throw new Error('transport should not be called');
        },
    });

    assert.equal(await provider.send(message()), 'UNAVAILABLE');
    assert.equal(calls, 0);
    assert.equal((await provider.health()).readiness, 'DISABLED');
});

test('FCM reports missing credentials without attempting delivery', async () => {
    let calls = 0;
    const provider = new FirebaseFcmProvider({
        ...baseOptions,
        privateKey: '',
        httpClient: async () => {
            calls += 1;
            throw new Error('transport should not be called');
        },
    });

    assert.equal(await provider.send(message()), 'UNAVAILABLE');
    assert.equal(calls, 0);
    assert.equal((await provider.health()).readiness, 'MISSING_CONFIGURATION');
});

test('FCM sends an authenticated data and notification payload', async () => {
    let request: { input: string; init: RequestInit } | undefined;
    const provider = new FirebaseFcmProvider({
        ...baseOptions,
        httpClient: async (input, init) => {
            request = { input, init };
            return { status: 200, ok: true, json: async () => ({ name: 'projects/paymuster-test/messages/1' }) };
        },
    });

    assert.equal(await provider.send(message()), 'SENT');
    assert.equal(request?.input, 'https://fcm.googleapis.com/v1/projects/paymuster-test/messages:send');
    assert.equal((request?.init.headers as Record<string, string>).authorization, 'Bearer test-access-token');
    const payload = JSON.parse(String(request?.init.body)) as { message: { token: string; data: Record<string, string> } };
    assert.equal(payload.message.token, token);
    assert.equal(payload.message.data.event_id, 'delivery-id');
    assert.equal(payload.message.data.deep_link, '/app/sites');
});

test('FCM classifies an unregistered token for cleanup', async () => {
    const provider = new FirebaseFcmProvider({
        ...baseOptions,
        httpClient: async () => ({
            status: 404,
            ok: false,
            json: async () => ({ error: { status: 'NOT_FOUND', message: 'UNREGISTERED token' } }),
        }),
    });

    assert.equal(await provider.send(message()), 'INVALID_TOKEN');
});

test('FCM retries transient responses with bounded exponential delays', async () => {
    let calls = 0;
    const waits: number[] = [];
    const provider = new FirebaseFcmProvider({
        ...baseOptions,
        sleep: async (milliseconds) => {
            waits.push(milliseconds);
        },
        httpClient: async () => {
            calls += 1;
            if (calls < 3) return { status: 503, ok: false, json: async () => ({}) };
            return { status: 200, ok: true, json: async () => ({}) };
        },
    });

    assert.equal(await provider.send(message()), 'SENT');
    assert.equal(calls, 3);
    assert.deepEqual(waits, [250, 500]);
});
