import crypto from 'node:crypto';

import { config } from '../lib/config.js';
import { AppError } from '../lib/app-error.js';
import type {
    PaymentOrder,
    PaymentOrderRequest,
    PaymentProvider,
    PaymentRefund,
    PaymentRefundRequest,
    PaymentReconciliation,
    ProviderHealth,
} from './contracts.js';

const RAZORPAY_API_URL = 'https://api.razorpay.com/v1';
const RAZORPAY_ORDERS_URL = `${RAZORPAY_API_URL}/orders`;
const MAX_RETRY_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 250;

type RazorpayOrderResponse = {
    id?: unknown;
    amount?: unknown;
    currency?: unknown;
    status?: unknown;
};

type RazorpayRefundResponse = {
    id?: unknown;
    payment_id?: unknown;
    amount?: unknown;
    currency?: unknown;
    status?: unknown;
};

type RazorpayPaymentResponse = {
    id?: unknown;
    order_id?: unknown;
    amount?: unknown;
    currency?: unknown;
    status?: unknown;
};

export interface RazorpayHttpResponse {
    readonly status: number;
    readonly ok: boolean;
    json(): Promise<unknown>;
}

export type RazorpayHttpClient = (
    input: string,
    init: RequestInit,
) => Promise<RazorpayHttpResponse>;

export interface RazorpayProviderOptions {
    enabled?: boolean;
    mode?: 'test' | 'live';
    keyId?: string;
    keySecret?: string;
    webhookSecret?: string;
    timeoutMs?: number;
    httpClient?: RazorpayHttpClient;
    sleep?: (milliseconds: number) => Promise<void>;
}

function defaultHttpClient(input: string, init: RequestInit): Promise<RazorpayHttpResponse> {
    return fetch(input, init);
}

function defaultSleep(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function isRetryableStatus(status: number): boolean {
    return status === 408 || status === 429 || status >= 500;
}

function safeEqual(left: string, right: string): boolean {
    const leftBuffer = Buffer.from(left, 'utf8');
    const rightBuffer = Buffer.from(right, 'utf8');
    return leftBuffer.length === rightBuffer.length && crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function hmacSha256(value: string, secret: string): string {
    return crypto.createHmac('sha256', secret).update(value, 'utf8').digest('hex');
}

function validateOrderRequest(request: PaymentOrderRequest): void {
    if (!request.organizationId || !request.userId || !request.receipt || !request.idempotencyKey) {
        throw new AppError('PAYMENT_REQUEST_INVALID', 'Payment order identity and idempotency fields are required.', 400);
    }
    if (!Number.isSafeInteger(Number(request.amountMinor)) || request.amountMinor <= 0n) {
        throw new AppError('PAYMENT_AMOUNT_INVALID', 'Payment amount must be a positive integer in minor currency units.', 400);
    }
    if (!/^[A-Z]{3}$/.test(request.currency)) {
        throw new AppError('PAYMENT_CURRENCY_INVALID', 'Payment currency must be a three-letter ISO code.', 400);
    }
}

function parseOrderResponse(payload: unknown, request: PaymentOrderRequest): PaymentOrder {
    const response = payload as RazorpayOrderResponse;
    if (
        typeof response.id !== 'string' ||
        typeof response.amount !== 'number' ||
        typeof response.currency !== 'string' ||
        typeof response.status !== 'string'
    ) {
        throw new AppError('PAYMENT_PROVIDER_INVALID_RESPONSE', 'Payment provider returned an invalid order response.', 502);
    }

    const expectedAmount = Number(request.amountMinor);
    if (response.amount !== expectedAmount || response.currency !== request.currency) {
        throw new AppError('PAYMENT_PROVIDER_AMOUNT_MISMATCH', 'Payment provider returned an unexpected order amount.', 502);
    }

    const status = response.status === 'paid' ? 'PAID' : response.status === 'attempted' ? 'FAILED' : 'CREATED';
    return {
        provider: 'razorpay',
        orderId: response.id,
        amountMinor: BigInt(response.amount),
        currency: response.currency,
        status,
    };
}

// API operations (order/refund/reconcile) require only the API key pair — this
// matches providerConfigurationSummary(), which reports Razorpay configured on
// keyId + keySecret. The webhook secret is a separate concern: when absent,
// webhook verification fails closed (verifyWebhookSignature returns false) and
// health reports a webhook-only degraded state (blueprint C6).
function providerIsConfigured(enabled: boolean, keyId: string, keySecret: string, _webhookSecret: string): boolean {
    return enabled && Boolean(keyId && keySecret);
}

function assertTestMode(mode: 'test' | 'live'): void {
    if (mode !== 'test') {
        throw new AppError('PAYMENT_LIVE_MODE_BLOCKED', 'Razorpay live mode is blocked until billing policy is approved.', 503);
    }
}

function normalizePaymentStatus(status: unknown): PaymentReconciliation['status'] {
    switch (status) {
        case 'created': return 'CREATED';
        case 'authorized': return 'AUTHORIZED';
        case 'captured': return 'CAPTURED';
        case 'failed': return 'FAILED';
        case 'refunded': return 'REFUNDED';
        default: return 'UNKNOWN';
    }
}

export class RazorpayProvider implements PaymentProvider {
    readonly name = 'razorpay';

    private readonly enabled: boolean;
    private readonly mode: 'test' | 'live';
    private readonly keyId: string;
    private readonly keySecret: string;
    private readonly webhookSecret: string;
    private readonly timeoutMs: number;
    private readonly httpClient: RazorpayHttpClient;
    private readonly sleep: (milliseconds: number) => Promise<void>;

    constructor(options: RazorpayProviderOptions = {}) {
        this.enabled = options.enabled ?? config.razorpayEnabled;
        this.mode = options.mode ?? config.razorpayMode;
        this.keyId = options.keyId ?? config.razorpayKeyId;
        this.keySecret = options.keySecret ?? config.razorpayKeySecret;
        this.webhookSecret = options.webhookSecret ?? config.razorpayWebhookSecret;
        this.timeoutMs = options.timeoutMs ?? config.razorpayTimeoutMs;
        this.httpClient = options.httpClient ?? defaultHttpClient;
        this.sleep = options.sleep ?? defaultSleep;
    }

    async createOrder(request: PaymentOrderRequest): Promise<PaymentOrder> {
        validateOrderRequest(request);
        if (!providerIsConfigured(this.enabled, this.keyId, this.keySecret, this.webhookSecret)) {
            throw new AppError('PAYMENT_UNAVAILABLE', 'Razorpay payments are disabled or not configured.', 503, {
                retryAfterSeconds: 60,
            });
        }
        assertTestMode(this.mode);

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
        try {
            let lastError: unknown = null;
            for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
                try {
                    const response = await this.httpClient(RAZORPAY_ORDERS_URL, {
                        method: 'POST',
                        signal: controller.signal,
                        headers: {
                            Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
                            'Content-Type': 'application/json',
                            'X-Request-Id': request.idempotencyKey,
                        },
                        body: JSON.stringify({
                            amount: Number(request.amountMinor),
                            currency: request.currency,
                            receipt: request.receipt,
                            notes: request.notes,
                        }),
                    });

                    if (!response.ok) {
                        const providerPayload = await response.json().catch(() => undefined);
                        const error = new AppError(
                            response.status === 429 ? 'PAYMENT_RATE_LIMITED' : 'PAYMENT_PROVIDER_ERROR',
                            'Razorpay could not create the payment order.',
                            response.status >= 500 || response.status === 429 ? 503 : 502,
                            { retryAfterSeconds: response.status === 429 ? 30 : undefined },
                        );
                        lastError = error;
                        if (!isRetryableStatus(response.status) || attempt === MAX_RETRY_ATTEMPTS) {
                            throw error;
                        }
                        void providerPayload;
                    } else {
                        return parseOrderResponse(await response.json(), request);
                    }
                } catch (error) {
                    lastError = error;
                    if (error instanceof AppError && error.code !== 'PAYMENT_PROVIDER_ERROR' && error.code !== 'PAYMENT_RATE_LIMITED') {
                        throw error;
                    }
                    if (attempt === MAX_RETRY_ATTEMPTS) break;
                }
                await this.sleep(INITIAL_RETRY_DELAY_MS * Math.pow(2, attempt - 1));
            }

            if (lastError instanceof AppError) throw lastError;
            throw new AppError('PAYMENT_PROVIDER_UNAVAILABLE', 'Razorpay is temporarily unavailable.', 503, {
                retryAfterSeconds: 30,
            });
        } catch (error) {
            if (error instanceof Error && error.name === 'AbortError') {
                throw new AppError('PAYMENT_TIMEOUT', 'Razorpay did not respond before the timeout.', 503, {
                    retryAfterSeconds: 30,
                });
            }
            throw error;
        } finally {
            clearTimeout(timeout);
        }
    }

    async refundPayment(request: PaymentRefundRequest): Promise<PaymentRefund> {
        if (!request.paymentId || !request.idempotencyKey || (request.amountMinor !== undefined && request.amountMinor <= 0n)) {
            throw new AppError('PAYMENT_REFUND_INVALID', 'Payment refund identity and amount must be valid.', 400);
        }
        if (!providerIsConfigured(this.enabled, this.keyId, this.keySecret, this.webhookSecret)) {
            throw new AppError('PAYMENT_UNAVAILABLE', 'Razorpay payments are disabled or not configured.', 503, {
                retryAfterSeconds: 60,
            });
        }
        assertTestMode(this.mode);

        const response = await this.requestProvider(`/payments/${encodeURIComponent(request.paymentId)}/refund`, {
            method: 'POST',
            headers: { 'X-Request-Id': request.idempotencyKey },
            body: JSON.stringify({
                ...(request.amountMinor !== undefined && { amount: Number(request.amountMinor) }),
                notes: request.notes,
            }),
        });
        const payload = response as RazorpayRefundResponse;
        if (
            typeof payload.id !== 'string' ||
            payload.payment_id !== request.paymentId ||
            typeof payload.amount !== 'number' ||
            typeof payload.currency !== 'string'
        ) {
            throw new AppError('PAYMENT_PROVIDER_INVALID_RESPONSE', 'Payment provider returned an invalid refund response.', 502);
        }

        return {
            provider: this.name,
            refundId: payload.id,
            paymentId: payload.payment_id,
            amountMinor: BigInt(payload.amount),
            currency: payload.currency,
            status: payload.status === 'processed' ? 'PROCESSED' : payload.status === 'failed' ? 'FAILED' : 'PENDING',
        };
    }

    async reconcilePayment(paymentId: string): Promise<PaymentReconciliation> {
        if (!paymentId) {
            throw new AppError('PAYMENT_ID_INVALID', 'Payment ID is required for reconciliation.', 400);
        }
        if (!providerIsConfigured(this.enabled, this.keyId, this.keySecret, this.webhookSecret)) {
            throw new AppError('PAYMENT_UNAVAILABLE', 'Razorpay payments are disabled or not configured.', 503, {
                retryAfterSeconds: 60,
            });
        }
        assertTestMode(this.mode);

        const payload = await this.requestProvider(`/payments/${encodeURIComponent(paymentId)}`, {
            method: 'GET',
        }) as RazorpayPaymentResponse;
        if (payload.id !== paymentId || typeof payload.id !== 'string') {
            throw new AppError('PAYMENT_PROVIDER_INVALID_RESPONSE', 'Payment provider returned an invalid reconciliation response.', 502);
        }

        return {
            provider: this.name,
            paymentId,
            orderId: typeof payload.order_id === 'string' ? payload.order_id : null,
            amountMinor: typeof payload.amount === 'number' ? BigInt(payload.amount) : null,
            currency: typeof payload.currency === 'string' ? payload.currency : null,
            status: normalizePaymentStatus(payload.status),
        };
    }

    private async requestProvider(path: string, init: RequestInit): Promise<unknown> {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
        let lastError: unknown = null;
        try {
            for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
                try {
                    const response = await this.httpClient(`${RAZORPAY_API_URL}${path}`, {
                        ...init,
                        signal: controller.signal,
                        headers: {
                            Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
                            'Content-Type': 'application/json',
                            ...init.headers,
                        },
                    });
                    if (response.ok) return await response.json();
                    lastError = new AppError(
                        response.status === 429 ? 'PAYMENT_RATE_LIMITED' : 'PAYMENT_PROVIDER_ERROR',
                        'Razorpay could not complete the payment request.',
                        isRetryableStatus(response.status) ? 503 : 502,
                        { retryAfterSeconds: response.status === 429 ? 30 : undefined },
                    );
                    if (!isRetryableStatus(response.status) || attempt === MAX_RETRY_ATTEMPTS) break;
                } catch (error) {
                    lastError = error;
                    if (attempt === MAX_RETRY_ATTEMPTS) break;
                }
                await this.sleep(INITIAL_RETRY_DELAY_MS * Math.pow(2, attempt - 1));
            }
            if (lastError instanceof AppError) throw lastError;
            throw new AppError('PAYMENT_PROVIDER_UNAVAILABLE', 'Razorpay is temporarily unavailable.', 503, {
                retryAfterSeconds: 30,
            });
        } catch (error) {
            if (error instanceof Error && error.name === 'AbortError') {
                throw new AppError('PAYMENT_TIMEOUT', 'Razorpay did not respond before the timeout.', 503, {
                    retryAfterSeconds: 30,
                });
            }
            throw error;
        } finally {
            clearTimeout(timeout);
        }
    }

    verifyCheckoutSignature(input: { orderId: string; paymentId: string; signature: string }): boolean {
        if (!this.keySecret || !input.orderId || !input.paymentId || !input.signature) return false;
        return safeEqual(hmacSha256(`${input.orderId}|${input.paymentId}`, this.keySecret), input.signature);
    }

    verifyWebhookSignature(rawBody: string, signature: string): boolean {
        if (!this.webhookSecret || !rawBody || !signature) return false;
        return safeEqual(hmacSha256(rawBody, this.webhookSecret), signature);
    }

    async health(): Promise<ProviderHealth> {
        const apiConfigured = Boolean(this.keyId && this.keySecret);
        const webhookConfigured = Boolean(this.webhookSecret);
        const enabled = this.enabled;
        return {
            provider: this.name,
            kind: 'PAYMENT',
            status: !enabled ? 'DISABLED' : !apiConfigured ? 'INVALID_CONFIGURATION' : 'ENABLED',
            readiness: !enabled
                ? 'DISABLED'
                : !apiConfigured
                    ? 'MISSING_CONFIGURATION'
                    : this.mode === 'test' ? 'READY' : 'ENVIRONMENT_BLOCKED',
            enabled,
            fallback: 'free-only-access',
            checkedAt: new Date().toISOString(),
            detail: !enabled
                ? 'Razorpay is disabled; no payment request is sent.'
                : !apiConfigured
                    ? 'Razorpay API credentials are incomplete.'
                    : this.mode !== 'test'
                        ? 'Live billing is blocked until production billing policy is approved.'
                        : apiConfigured && !webhookConfigured
                            ? 'Razorpay test mode API is configured; webhooks are degraded (empty signing value) — verification fails closed until it is set.'
                            : 'Razorpay test mode is configured; no live billing is enabled.',
        };
    }
}

export const razorpayProvider = new RazorpayProvider();
