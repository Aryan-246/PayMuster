import { config, providerConfigurationSummary } from '../lib/config.js';
import { emailService } from '../lib/email-service.js';
import type { AuthProvider, ProviderHealth, ProviderKind, ProviderHealthStatus, ProviderReadiness } from './contracts.js';
import { CloudinaryProvider, LocalStorageProvider } from './media.provider.js';
import { StreamProvider, existingRealtimeProvider } from './realtime.provider.js';
import { clerkAdapter } from './clerk.adapter.js';
import { razorpayProvider } from './razorpay.provider.js';
import { storedCoordinateMapsProvider } from './maps.provider.js';
import { firebaseFcmProvider } from './firebase-fcm.provider.js';
import { observability } from '../lib/observability.js';
import { algoliaProvider } from './algolia.provider.js';
import { brevoProvider } from './brevo.provider.js';
import { redisProvider } from './redis.provider.js';
import { sentryProvider } from './sentry.provider.js';
import { getProviderUse } from './usage-tracker.js';

function now(): string {
    return new Date().toISOString();
}

function configuredHealth(
    provider: string,
    kind: ProviderKind,
    enabled: boolean,
    configured: boolean,
    fallback?: string,
    supported = true,
): ProviderHealth {
    let status: ProviderHealthStatus = 'DISABLED';
    let readiness: ProviderReadiness = 'DISABLED';
    let detail: string | undefined;
    if (enabled && !supported) {
        status = 'ENVIRONMENT_BLOCKED';
        readiness = 'ENVIRONMENT_BLOCKED';
        detail = 'Provider is intentionally blocked until its environment and operational policy are approved.';
    } else if (enabled && !configured) {
        status = 'INVALID_CONFIGURATION';
        readiness = 'MISSING_CONFIGURATION';
        detail = 'Provider is enabled but required server configuration is incomplete.';
    } else if (enabled) {
        // Enabled + configured + not live-verified is a WORKING state, not an
        // outage. The old "UNAVAILABLE + readiness READY" pairing read as a
        // contradiction; operations are verified per use.
        status = 'ENABLED';
        readiness = 'READY';
        detail = 'Provider is enabled and configured; live operation is verified per use.';
    }
    return {
        provider,
        kind,
        status,
        readiness,
        enabled,
        fallback,
        checkedAt: now(),
        detail,
    };
}

function summaryHealth(summary: ReturnType<typeof providerConfigurationSummary>[number]): ProviderHealth {
    return configuredHealth(
        summary.provider,
        summary.kind,
        summary.enabled,
        summary.configured,
        summary.fallback,
        summary.readiness !== 'ENVIRONMENT_BLOCKED',
    );
}

class ExistingPayMusterAuth implements AuthProvider {
    readonly name = 'paymuster';

    async capabilities() {
        return {
            provider: this.name,
            password: true,
            google: Boolean(config.googleClientId),
            passkeys: false,
            organizations: true,
            sessionRevocation: true,
        };
    }

    async health(): Promise<ProviderHealth> {
        return {
            provider: this.name,
            kind: 'AUTH',
            status: 'CONNECTED',
            readiness: 'READY',
            enabled: true,
            checkedAt: now(),
            detail: 'Existing PayMuster JWT/session authentication is authoritative.',
        };
    }
}

export const authProvider = new ExistingPayMusterAuth();

/**
 * Firebase Web config health — checks whether web push configuration is present.
 * This is separate from FCM Admin SDK (which requires a service account).
 */
function firebaseWebConfigHealth(): ProviderHealth {
    const hasWebConfig = Boolean(
        config.firebaseWebApiKey &&
        config.firebaseAppId &&
        config.firebaseProjectId,
    );
    const hasVapid = Boolean(config.firebaseVapidKey);

    if (!hasWebConfig) {
        return {
            provider: 'firebase-web',
            kind: 'PUSH',
            status: 'DISABLED',
            enabled: false,
            fallback: 'in-app-notification',
            checkedAt: now(),
            detail: 'Firebase Web configuration is not provided.',
        };
    }

    return {
        provider: 'firebase-web',
        kind: 'PUSH',
        status: 'CONNECTED',
        readiness: 'READY',
        enabled: true,
        fallback: 'in-app-notification',
        checkedAt: now(),
        detail: hasVapid
            ? 'Firebase Web client configuration is present for client-side push notifications.'
            : 'Firebase Web client configuration is present.',
    };
}

/**
 * Gemini health reflects REAL request outcomes: the usage tracker records
 * every successful model call made by the AI service, so the admin sees
 * CONNECTED (with the last success time) instead of a contradiction.
 */
function geminiHealth(summary: ReturnType<typeof providerConfigurationSummary>[number]): ProviderHealth {
    if (!summary.enabled || !summary.configured) {
        return configuredHealth(summary.provider, summary.kind, summary.enabled, summary.configured, summary.fallback);
    }
    const use = getProviderUse('gemini');
    if (use && use.successCount > 0) {
        return {
            provider: 'gemini',
            kind: 'AI',
            status: 'CONNECTED',
            readiness: 'READY',
            enabled: true,
            fallback: summary.fallback,
            checkedAt: now(),
            detail: `Gemini model ${config.geminiModel} completed ${use.successCount} live request(s); last success ${use.lastSuccessAt.toISOString()}.`,
        };
    }
    if (use && use.failureCount > 0 && use.successCount === 0) {
        return {
            provider: 'gemini',
            kind: 'AI',
            status: 'UNAVAILABLE',
            readiness: 'READY',
            enabled: true,
            fallback: summary.fallback,
            checkedAt: now(),
            detail: `Gemini is configured but every live request so far has failed; last error: ${use.lastError ?? 'unknown'}.`,
        };
    }
    return {
        provider: 'gemini',
        kind: 'AI',
        status: 'ENABLED',
        readiness: 'READY',
        enabled: true,
        fallback: summary.fallback,
        checkedAt: now(),
        detail: 'Gemini API credentials are configured; live model requests are verified per use.',
    };
}

/**
 * Single Sentry entry. Observability policy and SDK initialization are one
 * concern for the admin — reporting both an "environment blocked" row and a
 * "connected" row for the same provider read as a contradiction.
 */
function sentryHealth(): ProviderHealth {
    if (!config.sentryEnabled) {
        return sentryProvider.health();
    }
    const sdk = sentryProvider.health(); // initializes on first call
    if (sdk.status === 'CONNECTED') {
        return sdk;
    }
    const policy = observability.health();
    return {
        provider: 'sentry',
        kind: 'OBSERVABILITY',
        status: 'ENVIRONMENT_BLOCKED',
        readiness: 'ENVIRONMENT_BLOCKED',
        enabled: true,
        fallback: 'structured-logger',
        checkedAt: now(),
        detail: `${policy.detail} (SDK status: ${sdk.detail ?? 'not initialized'})`,
    };
}

export async function providerHealth(): Promise<ProviderHealth[]> {
    const cloudinary = new CloudinaryProvider();
    const localStorage = new LocalStorageProvider();
    const stream = new StreamProvider();
    const summaries = providerConfigurationSummary();
    const summary = (provider: string) => summaries.find((item) => item.provider === provider)!;

    // Initialize Sentry if enabled
    if (config.sentryEnabled) {
        sentryProvider.initialize();
    }

    return [
        // AI
        geminiHealth(summary('gemini')),
        // Search
        await algoliaProvider.health(),
        // Media/Storage
        await cloudinary.health(),
        await localStorage.health(),
        // Realtime
        await stream.health(),
        await existingRealtimeProvider.health(),
        // Auth
        await clerkAdapter.health(),
        await authProvider.health(),
        // Email
        await emailService.health(),
        await brevoProvider.health(),
        // Payments
        await razorpayProvider.health(),
        // Push notifications
        await firebaseFcmProvider.health(),
        firebaseWebConfigHealth(),
        // Maps
        summaryHealth(summary('google-maps')),
        await storedCoordinateMapsProvider.health(),
        // Observability — ONE Sentry entry (policy + SDK state merged).
        sentryHealth(),
        // Cache
        await redisProvider.health(),
        // Infrastructure (blocked)
        summaryHealth(summary('twilio')),
        summaryHealth(summary('aws')),
    ];
}

export function redactProviderConfiguration() {
    return {
        providers: providerConfigurationSummary(),
        auth: { provider: authProvider.name, sessionRevocation: true, passkeys: false },
    };
}

// Re-export providers for service-level consumption
export { algoliaProvider } from './algolia.provider.js';
export { brevoProvider } from './brevo.provider.js';
export { redisProvider } from './redis.provider.js';
export { sentryProvider } from './sentry.provider.js';
