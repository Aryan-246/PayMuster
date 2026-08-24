import assert from 'node:assert/strict';
import test from 'node:test';

import { ObservabilityReporter, type ObservabilityEvent } from './observability.js';

test('observability reports a redacted, correlation-aware exception', () => {
    const events: ObservabilityEvent[] = [];
    const reporter = new ObservabilityReporter({
        enabled: true,
        environment: 'test',
        sink: {
            capture: (event) => {
                events.push(event);
            },
        },
    });

    const error = Object.assign(new Error('provider failed'), { code: 'PROVIDER_FAILED', status: 503 });
    reporter.captureException(error, {
        requestId: 'request-123',
        provider: 'smtp',
        orgId: 'org-123',
        authorization: 'Bearer should-not-leak',
        nested: { apiKey: 'secret-value', safe: 'visible' },
    });

    assert.equal(events.length, 1);
    assert.equal(events[0].environment, 'test');
    assert.equal(events[0].context.requestId, 'request-123');
    assert.equal(events[0].context.authorization, '[REDACTED]');
    assert.deepEqual(events[0].context.nested, { apiKey: '[REDACTED]', safe: 'visible' });
    assert.deepEqual(events[0].error, {
        name: 'Error',
        message: 'provider failed',
        code: 'PROVIDER_FAILED',
        status: 503,
    });
});

test('observability falls back when disabled and does not throw on sink failure', () => {
    const fallbackEvents: ObservabilityEvent[] = [];
    const disabled = new ObservabilityReporter({
        enabled: false,
        fallback: (event) => {
            fallbackEvents.push(event);
        },
    });
    disabled.captureMessage('disabled event');

    const failingSink = new ObservabilityReporter({
        enabled: true,
        sink: { capture: () => { throw new Error('telemetry unavailable'); } },
        fallback: (event) => {
            fallbackEvents.push(event);
        },
    });
    assert.doesNotThrow(() => failingSink.captureMessage('event with failing sink'));

    assert.equal(fallbackEvents.length, 2);
    assert.equal(fallbackEvents[0].message, 'disabled event');
    assert.equal(fallbackEvents[1].message, 'Observability sink failed');
});
