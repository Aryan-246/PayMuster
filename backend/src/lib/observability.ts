import { config } from './config.js';
import { logger } from './logger.js';
import type { ProviderHealth } from '../providers/contracts.js';

export type ObservabilityLevel = 'info' | 'warning' | 'error' | 'fatal';

export interface ObservabilityContext {
    requestId?: string;
    provider?: string;
    operation?: string;
    userId?: string;
    orgId?: string | null;
    siteId?: string | null;
    [key: string]: unknown;
}

export interface ObservabilityEvent {
    message: string;
    level: ObservabilityLevel;
    error?: {
        name: string;
        message: string;
        code?: string;
        status?: number;
    };
    context: Record<string, unknown>;
    environment: string;
}

export interface ObservabilitySink {
    capture(event: ObservabilityEvent): void | Promise<void>;
}

export interface ObservabilityReporterOptions {
    enabled?: boolean;
    environment?: string;
    sink?: ObservabilitySink | null;
    fallback?: (event: ObservabilityEvent) => void;
}

const sensitiveFieldPattern = /password|otp|token|secret|authorization|cookie|credential|private.?key|api.?key|dsn/i;
const MAX_STRING_LENGTH = 500;

function redact(value: unknown, fieldName = '', seen = new WeakSet<object>()): unknown {
    if (sensitiveFieldPattern.test(fieldName)) return '[REDACTED]';
    if (typeof value === 'string') {
        return value.length > MAX_STRING_LENGTH ? value.slice(0, MAX_STRING_LENGTH) + '...' : value;
    }
    if (typeof value !== 'object' || value === null) return value;
    if (seen.has(value)) return '[CIRCULAR]';
    seen.add(value);

    if (value instanceof Error) {
        const error = value as Error & { code?: string; status?: number };
        return {
            name: error.name,
            message: error.message,
            code: error.code,
            status: error.status,
        };
    }

    if (Array.isArray(value)) return value.map((item) => redact(item, '', seen));

    return Object.fromEntries(
        Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, redact(item, key, seen)]),
    );
}

function errorDetails(error: unknown): ObservabilityEvent['error'] | undefined {
    if (!(error instanceof Error)) return undefined;
    const candidate = error as Error & { code?: string; status?: number };
    return {
        name: error.name,
        message: error.message,
        code: candidate.code,
        status: candidate.status,
    };
}

export class ObservabilityReporter {
    private readonly enabled: boolean;
    private readonly environment: string;
    private readonly sink: ObservabilitySink | null;
    private readonly fallback: (event: ObservabilityEvent) => void;

    constructor(options: ObservabilityReporterOptions = {}) {
        this.enabled = options.enabled ?? config.sentryEnabled;
        this.environment = options.environment ?? config.sentryEnvironment;
        this.sink = options.sink ?? null;
        this.fallback = options.fallback ?? ((event) => logger.error('observability.event', event));
    }

    health(): ProviderHealth {
        const configured = Boolean(config.sentryDsn);
        return {
            provider: 'sentry',
            kind: 'OBSERVABILITY',
            status: !this.enabled ? 'DISABLED' : 'UNAVAILABLE',
            readiness: !this.enabled ? 'DISABLED' : 'ENVIRONMENT_BLOCKED',
            enabled: this.enabled,
            fallback: 'structured-logger',
            checkedAt: new Date().toISOString(),
            detail: !this.enabled
                ? 'Observability is disabled and uses the redacted structured logger.'
                : configured
                    ? 'Sentry configuration is present, but external transport is blocked; redacted structured logging remains authoritative.'
                    : 'Sentry external transport is blocked and the configured DSN is incomplete.',
        };
    }

    captureException(error: unknown, context: ObservabilityContext = {}): void {
        const message = error instanceof Error ? error.message : 'Unhandled application error';
        this.emit({ message, level: 'error', error: errorDetails(error), context });
    }

    captureMessage(message: string, level: ObservabilityLevel = 'info', context: ObservabilityContext = {}): void {
        this.emit({ message, level, context });
    }

    private emit(input: Omit<ObservabilityEvent, 'environment' | 'context'> & { context: ObservabilityContext }): void {
        const event: ObservabilityEvent = {
            ...input,
            environment: this.environment,
            context: redact(input.context) as Record<string, unknown>,
        };

        if (this.enabled && this.sink) {
            try {
                void this.sink.capture(event);
            } catch (sinkError) {
                this.fallback({
                    message: 'Observability sink failed',
                    level: 'warning',
                    error: errorDetails(sinkError),
                    context: { requestId: event.context.requestId },
                    environment: this.environment,
                });
            }
            return;
        }

        this.fallback(event);
    }
}

export const observability = new ObservabilityReporter();
