import { GoogleAuth } from 'google-auth-library';

import { config } from '../lib/config.js';
import type { ProviderHealth, PushMessage, PushProvider } from './contracts.js';
import { getProviderUse, recordProviderFailure, recordProviderSuccess } from './usage-tracker.js';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const MAX_RETRY_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 250;

export interface FirebaseHttpResponse {
    readonly status: number;
    readonly ok: boolean;
    json(): Promise<unknown>;
}

export type FirebaseHttpClient = (
    input: string,
    init: RequestInit,
) => Promise<FirebaseHttpResponse>;

export interface FirebaseFcmProviderOptions {
    enabled?: boolean;
    projectId?: string;
    clientEmail?: string;
    privateKey?: string;
    timeoutMs?: number;
    httpClient?: FirebaseHttpClient;
    accessTokenProvider?: () => Promise<string>;
    sleep?: (milliseconds: number) => Promise<void>;
}

function defaultHttpClient(input: string, init: RequestInit): Promise<FirebaseHttpResponse> {
    return fetch(input, init);
}

function defaultSleep(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function isRetryableStatus(status: number): boolean {
    return status === 408 || status === 429 || status >= 500;
}

function isInvalidTokenResponse(status: number, payload: unknown): boolean {
    if (status === 404) return true;
    const serialized = JSON.stringify(payload).toUpperCase();
    return serialized.includes('UNREGISTERED') || serialized.includes('INVALID_ARGUMENT');
}

function errorCode(payload: unknown): string {
    if (payload && typeof payload === 'object') {
        const error = (payload as { error?: { status?: unknown; message?: unknown } }).error;
        if (typeof error?.status === 'string') return error.status;
        if (typeof error?.message === 'string' && error.message.length > 0) return error.message.slice(0, 120);
    }
    return 'FCM_REQUEST_FAILED';
}

export class FirebaseFcmProvider implements PushProvider {
    readonly name = 'firebase-fcm';

    private readonly enabled: boolean;
    private readonly projectId: string;
    private readonly clientEmail: string;
    private readonly privateKey: string;
    private readonly timeoutMs: number;
    private readonly httpClient: FirebaseHttpClient;
    private readonly accessTokenProvider?: () => Promise<string>;
    private readonly sleep: (milliseconds: number) => Promise<void>;

    constructor(options: FirebaseFcmProviderOptions = {}) {
        this.enabled = options.enabled ?? config.fcmEnabled;
        this.projectId = options.projectId ?? config.firebaseProjectId;
        this.clientEmail = options.clientEmail ?? config.firebaseClientEmail;
        this.privateKey = options.privateKey ?? config.firebasePrivateKey;
        this.timeoutMs = options.timeoutMs ?? config.fcmTimeoutMs;
        this.httpClient = options.httpClient ?? defaultHttpClient;
        this.accessTokenProvider = options.accessTokenProvider;
        this.sleep = options.sleep ?? defaultSleep;
    }

    private isConfigured(): boolean {
        return Boolean(this.projectId && this.clientEmail && this.privateKey);
    }

    private async getAccessToken(): Promise<string> {
        if (this.accessTokenProvider) return this.accessTokenProvider();
        const auth = new GoogleAuth({
            credentials: {
                client_email: this.clientEmail,
                private_key: this.privateKey,
            },
            scopes: [FCM_SCOPE],
        });
        const token = await auth.getAccessToken();
        if (!token) throw new Error('Firebase access token was not returned.');
        return token;
    }

    async send(message: PushMessage): Promise<'SENT' | 'INVALID_TOKEN' | 'UNAVAILABLE'> {
        if (!this.enabled || !this.isConfigured()) return 'UNAVAILABLE';

        let accessToken: string;
        try {
            accessToken = await this.getAccessToken();
        } catch {
            recordProviderFailure(this.name, 'FCM access token could not be acquired.');
            return 'UNAVAILABLE';
        }

        const endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/messages:send`;
        const body = JSON.stringify({
            message: {
                token: message.token,
                notification: { title: message.title, body: message.body },
                data: { ...message.data, event_id: message.eventId },
            },
        });

        for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt += 1) {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
            try {
                const response = await this.httpClient(endpoint, {
                    method: 'POST',
                    headers: {
                        authorization: `Bearer ${accessToken}`,
                        'content-type': 'application/json',
                    },
                    body,
                    signal: controller.signal,
                });
                const payload = await response.json().catch(() => null);
                if (response.ok) {
                    recordProviderSuccess(this.name);
                    return 'SENT';
                }
                if (isInvalidTokenResponse(response.status, payload)) {
                    // A rejected token is a recipient problem, not a provider outage.
                    recordProviderSuccess(this.name);
                    return 'INVALID_TOKEN';
                }
                if (!isRetryableStatus(response.status) || attempt === MAX_RETRY_ATTEMPTS) {
                    recordProviderFailure(this.name, `FCM responded ${response.status}.`);
                    return 'UNAVAILABLE';
                }
            } catch {
                if (attempt === MAX_RETRY_ATTEMPTS) {
                    recordProviderFailure(this.name, 'FCM request failed after retries.');
                    return 'UNAVAILABLE';
                }
            } finally {
                clearTimeout(timeout);
            }
            await this.sleep(INITIAL_RETRY_DELAY_MS * 2 ** (attempt - 1));
        }

        recordProviderFailure(this.name, 'FCM send exhausted retries.');
        return 'UNAVAILABLE';
    }

    async health(): Promise<ProviderHealth> {
        const configured = this.isConfigured();
        if (!this.enabled) {
            return {
                provider: this.name,
                kind: 'PUSH',
                status: 'DISABLED',
                readiness: 'DISABLED',
                enabled: false,
                fallback: 'in-app-notification',
                checkedAt: new Date().toISOString(),
                detail: 'FCM delivery is disabled; durable in-app notifications remain active.',
            };
        }
        if (!configured) {
            return {
                provider: this.name,
                kind: 'PUSH',
                status: 'INVALID_CONFIGURATION',
                readiness: 'MISSING_CONFIGURATION',
                enabled: true,
                fallback: 'in-app-notification',
                checkedAt: new Date().toISOString(),
                detail: 'FCM is enabled but FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, or FIREBASE_PRIVATE_KEY is missing.',
            };
        }
        // Delivery health is verified on send — report what actually happened.
        const use = getProviderUse(this.name);
        if (use && use.successCount > 0) {
            return {
                provider: this.name,
                kind: 'PUSH',
                status: 'CONNECTED',
                readiness: 'READY',
                enabled: true,
                fallback: 'in-app-notification',
                checkedAt: new Date().toISOString(),
                detail: `FCM has delivered ${use.successCount} push notification(s); last success ${use.lastSuccessAt.toISOString()}.`,
            };
        }
        if (use && use.failureCount > 0 && use.successCount === 0) {
            return {
                provider: this.name,
                kind: 'PUSH',
                status: 'UNAVAILABLE',
                readiness: 'READY',
                enabled: true,
                fallback: 'in-app-notification',
                checkedAt: new Date().toISOString(),
                detail: `FCM is configured but every delivery attempt so far has failed; last error: ${use.lastError ?? 'unknown'}.`,
            };
        }
        return {
            provider: this.name,
            kind: 'PUSH',
            status: 'ENABLED',
            readiness: 'READY',
            enabled: true,
            fallback: 'in-app-notification',
            checkedAt: new Date().toISOString(),
            detail: 'FCM credentials are configured; delivery health is verified on send.',
        };
    }
}

export const firebaseFcmProvider = new FirebaseFcmProvider();

export function firebaseErrorCode(payload: unknown): string {
    return errorCode(payload);
}
