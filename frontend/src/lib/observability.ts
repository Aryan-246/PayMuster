export type ObservabilityLevel = 'info' | 'warning' | 'error' | 'fatal';

export interface ObservabilityContext {
    requestId?: string;
    provider?: string;
    operation?: string;
    status?: number;
    code?: string;
    [key: string]: unknown;
}

export interface ObservabilityEvent {
    message: string;
    level: ObservabilityLevel;
    context: Record<string, unknown>;
    environment: string;
}

export interface ObservabilitySink {
    capture(event: ObservabilityEvent): void;
}

const sensitiveFieldPattern = /password|otp|token|secret|authorization|cookie|credential|private.?key|api.?key|dsn/i;
const environment = import.meta.env.VITE_SENTRY_ENVIRONMENT || import.meta.env.MODE;

function redact(value: unknown, fieldName = ''): unknown {
    if (sensitiveFieldPattern.test(fieldName)) return '[REDACTED]';
    if (typeof value === 'string') return value.length > 500 ? value.slice(0, 500) + '...' : value;
    if (Array.isArray(value)) return value.map((item) => redact(item));
    if (value && typeof value === 'object') {
        return Object.fromEntries(
            Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, redact(item, key)]),
        );
    }
    return value;
}

export class ObservabilityReporter {
    constructor(
        private readonly enabled = import.meta.env.VITE_SENTRY_ENABLED === 'true',
        private readonly sink: ObservabilitySink | null = null,
    ) { }

    captureException(error: unknown, context: ObservabilityContext = {}): void {
        const message = error instanceof Error ? error.message : 'Unexpected frontend error';
        this.emit({ message, level: 'error', context });
    }

    captureMessage(message: string, level: ObservabilityLevel = 'info', context: ObservabilityContext = {}): void {
        this.emit({ message, level, context });
    }

    private emit(input: Omit<ObservabilityEvent, 'environment' | 'context'> & { context: ObservabilityContext }): void {
        const event: ObservabilityEvent = {
            ...input,
            environment,
            context: redact(input.context) as Record<string, unknown>,
        };
        if (this.enabled && this.sink) {
            this.sink.capture(event);
        }
    }
}

export const observability = new ObservabilityReporter();
