import { createRequire } from 'node:module';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth } from './contracts.js';

const require = createRequire(import.meta.url);

function now(): string {
    return new Date().toISOString();
}

/**
 * Sentry observability provider — error tracking and performance monitoring.
 * Integrates with the existing observability.ts module, adding real Sentry
 * event capture when configured. Falls back to structured logger.
 */
export class SentryProvider {
    readonly name = 'sentry';
    private sentry: any = null;
    private initialized = false;
    private initError: string | null = null;

    initialize(): void {
        if (this.initialized) return;
        this.initialized = true;

        if (!config.sentryEnabled || !config.sentryDsn) {
            this.initError = 'Sentry is not enabled or DSN is missing.';
            return;
        }

        try {
            const Sentry = require('@sentry/node');
            Sentry.init({
                dsn: config.sentryDsn,
                environment: config.sentryEnvironment,
                tracesSampleRate: 0.1,
                debug: false,
                beforeSend(event: any) {
                    if (event.request?.headers) {
                        delete event.request.headers['authorization'];
                        delete event.request.headers['cookie'];
                        delete event.request.headers['x-api-key'];
                    }
                    if (event.request) {
                        delete event.request.data;
                    }
                    return event;
                },
            });
            this.sentry = Sentry;
            logger.info('sentry.initialized', { environment: config.sentryEnvironment });
        } catch (err: any) {
            this.initError = `Sentry SDK not available: ${err.message}`;
            logger.warn('sentry.sdk_not_available', { error: err.message });
        }
    }

    health(): ProviderHealth {
        if (!config.sentryEnabled) {
            return {
                provider: 'sentry',
                kind: 'OBSERVABILITY',
                status: 'DISABLED',
                readiness: 'DISABLED',
                enabled: false,
                fallback: 'structured-logger',
                checkedAt: now(),
                detail: 'Sentry error reporting is disabled.',
            };
        }

        if (!this.initialized) {
            this.initialize();
        }

        if (this.sentry) {
            return {
                provider: 'sentry',
                kind: 'OBSERVABILITY',
                status: 'CONNECTED',
                readiness: 'READY',
                enabled: true,
                fallback: 'structured-logger',
                checkedAt: now(),
                detail: `Sentry initialized with environment: ${config.sentryEnvironment}`,
            };
        }

        return {
            provider: 'sentry',
            kind: 'OBSERVABILITY',
            status: 'UNAVAILABLE',
            readiness: 'ENVIRONMENT_BLOCKED',
            enabled: true,
            fallback: 'structured-logger',
            checkedAt: now(),
            detail: this.initError || 'Sentry SDK not available. DSN is configured for use when SDK is present.',
        };
    }

    captureException(error: Error, context?: Record<string, unknown>): void {
        if (this.sentry) {
            this.sentry.withScope((scope: any) => {
                if (context) {
                    Object.entries(context).forEach(([key, value]) => {
                        scope.setExtra(key, value);
                    });
                }
                this.sentry.captureException(error);
            });
        }
        logger.error('exception.captured', error, context);
    }

    captureMessage(message: string, level: 'info' | 'warning' | 'error' = 'info', context?: Record<string, unknown>): void {
        if (this.sentry) {
            this.sentry.withScope((scope: any) => {
                if (context) {
                    Object.entries(context).forEach(([key, value]) => {
                        scope.setExtra(key, value);
                    });
                }
                this.sentry.captureMessage(message, level);
            });
        }
        logger.info('message.captured', { message, level, ...context });
    }

    async testCapture(): Promise<{ sent: boolean; eventId?: string; error?: string }> {
        if (!this.initialized) {
            this.initialize();
        }

        if (!this.sentry) {
            return {
                sent: false,
                error: this.initError || 'Sentry not initialized. DSN configured but SDK not installed.',
            };
        }

        try {
            const eventId = this.sentry.captureMessage(
                '[PayMuster] Sentry integration test — safe development event',
                'info',
            );
            await this.sentry.flush(5000);
            return { sent: true, eventId };
        } catch (err: any) {
            return { sent: false, error: err.message };
        }
    }

    getSentryDsnConfig() {
        return {
            backend: config.sentryDsn || null,
            frontend: config.sentryFrontendDsn || null,
            mobile: config.sentryMobileDsn || null,
            environment: config.sentryEnvironment,
        };
    }
}

export const sentryProvider = new SentryProvider();
