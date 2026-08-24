import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { RazorpayProvider } from './razorpay.provider.js';

function response(status: number, payload: unknown) {
    return {
        status,
        ok: status >= 200 && status < 300,
        json: async () => payload,
    };
}

const request = {
    organizationId: 'org-id',
    userId: 'user-id',
    amountMinor: 12500n,
    currency: 'INR',
    receipt: 'receipt-001',
    notes: { purpose: 'trial-upgrade' },
    idempotencyKey: 'request-001',
};

test('Razorpay remains disabled without making an HTTP request', async () => {
    let calls = 0;
    const provider = new RazorpayProvider({
        enabled: false,
        httpClient: async () => {
            calls += 1;
            return response(200, {});
        },
    });

    await assert.rejects(provider.createOrder(request), { code: 'PAYMENT_UNAVAILABLE' });
    assert.equal(calls, 0);
    assert.equal((await provider.health()).readiness, 'DISABLED');
});

test('Razorpay creates a test order and forwards idempotency metadata', async () => {
    let receivedUrl = '';
    let receivedInit: RequestInit | undefined;
    const provider = new RazorpayProvider({
        enabled: true,
        mode: 'test',
        keyId: 'rzp_test_id',
        keySecret: 'server-test-secret',
        webhookSecret: 'webhook-test-secret',
        httpClient: async (url, init) => {
            receivedUrl = url;
            receivedInit = init;
            return response(200, { id: 'order_123', amount: 12500, currency: 'INR', status: 'created' });
        },
    });

    const order = await provider.createOrder(request);
    assert.equal(receivedUrl, 'https://api.razorpay.com/v1/orders');
    assert.equal((receivedInit?.headers as Record<string, string>)['X-Request-Id'], 'request-001');
    assert.deepEqual(JSON.parse(String(receivedInit?.body)), {
        amount: 12500,
        currency: 'INR',
        receipt: 'receipt-001',
        notes: { purpose: 'trial-upgrade' },
    });
    assert.equal(order.orderId, 'order_123');
    assert.equal(order.amountMinor, 12500n);
    assert.equal(order.status, 'CREATED');
});

test('Razorpay retries a rate-limited response and succeeds without exposing credentials', async () => {
    let calls = 0;
    const delays: number[] = [];
    const provider = new RazorpayProvider({
        enabled: true,
        mode: 'test',
        keyId: 'rzp_test_id',
        keySecret: 'server-test-secret',
        webhookSecret: 'webhook-test-secret',
        httpClient: async () => {
            calls += 1;
            return calls === 1
                ? response(429, { error: { description: 'rate limited' } })
                : response(200, { id: 'order_456', amount: 12500, currency: 'INR', status: 'created' });
        },
        sleep: async (milliseconds) => {
            delays.push(milliseconds);
        },
    });

    const order = await provider.createOrder(request);
    assert.equal(order.orderId, 'order_456');
    assert.equal(calls, 2);
    assert.deepEqual(delays, [250]);
});

test('Razorpay verifies checkout and webhook signatures with constant-time-safe values', () => {
    const provider = new RazorpayProvider({
        enabled: true,
        mode: 'test',
        keyId: 'rzp_test_id',
        keySecret: 'server-test-secret',
        webhookSecret: 'webhook-test-secret',
    });

    const checkoutOrderId = 'order_123';
    const checkoutPaymentId = 'pay_123';
    const checkoutSignature = crypto
        .createHmac('sha256', 'server-test-secret')
        .update(`${checkoutOrderId}|${checkoutPaymentId}`)
        .digest('hex');
    const webhookBody = '{"event":"payment.captured"}';
    const webhookSignature = crypto
        .createHmac('sha256', 'webhook-test-secret')
        .update(webhookBody)
        .digest('hex');

    assert.equal(provider.verifyCheckoutSignature({ orderId: checkoutOrderId, paymentId: checkoutPaymentId, signature: checkoutSignature }), true);
    assert.equal(provider.verifyCheckoutSignature({ orderId: checkoutOrderId, paymentId: checkoutPaymentId, signature: `${checkoutSignature}x` }), false);
    assert.equal(provider.verifyWebhookSignature(webhookBody, webhookSignature), true);
    assert.equal(provider.verifyWebhookSignature(webhookBody, 'invalid'), false);
});

test('Razorpay live mode is blocked even when credentials are present', async () => {
    const provider = new RazorpayProvider({
        enabled: true,
        mode: 'live',
        keyId: 'rzp_live_id',
        keySecret: 'server-live-secret',
        webhookSecret: 'webhook-live-secret',
    });

    await assert.rejects(provider.createOrder(request), { code: 'PAYMENT_LIVE_MODE_BLOCKED' });
    assert.equal((await provider.health()).readiness, 'ENVIRONMENT_BLOCKED');
});
