import assert from 'node:assert/strict';
import test from 'node:test';

import { providerHealth, redactProviderConfiguration, authProvider } from './registry.js';

const VALID_STATUSES = [
    'CONNECTED',
    'ENABLED',
    'DISABLED',
    'INVALID_CONFIGURATION',
    'NOT_CONFIGURED',
    'ENVIRONMENT_BLOCKED',
    'RATE_LIMITED',
    'UNAVAILABLE',
];

test('provider registry reports safe disabled or configured states without secrets', async () => {
    const health = await providerHealth();
    assert.ok(health.length >= 6);
    for (const item of health) {
        assert.ok(VALID_STATUSES.includes(item.status), `invalid status ${item.status} for ${item.provider}`);
        assert.equal(typeof item.enabled, 'boolean');
        assert.equal(typeof item.checkedAt, 'string');
        assert.doesNotMatch(JSON.stringify(item), /secret|key|password|token/i);
    }

    const configuration = redactProviderConfiguration();
    const providerNames = configuration.providers.map((provider) => provider.provider);
    assert.ok(providerNames.includes('gemini'));
    assert.ok(providerNames.includes('razorpay'));
    assert.ok(providerNames.includes('firebase-fcm'));
    assert.ok(providerNames.includes('sentry'));
    assert.equal(configuration.auth.provider, 'paymuster');
    assert.equal(configuration.auth.sessionRevocation, true);
    const redisSummary = configuration.providers.find((provider) => provider.provider === 'redis');
    assert.ok(['READY', 'DISABLED', 'MISSING_CONFIGURATION', 'ENVIRONMENT_BLOCKED'].includes(redisSummary?.readiness as any));
    assert.equal(configuration.providers.find((provider) => provider.provider === 'twilio')?.readiness, 'DISABLED');
    assert.equal(configuration.providers.find((provider) => provider.provider === 'aws')?.readiness, 'DISABLED');

    for (const provider of ['algolia', 'cloudinary', 'stream', 'clerk', 'sentry']) {
        const summary = configuration.providers.find((item) => item.provider === provider);
        assert.ok(['READY', 'DISABLED', 'MISSING_CONFIGURATION', 'INVALID_CONFIGURATION', 'ENVIRONMENT_BLOCKED'].includes(summary?.readiness as any));
        assert.equal(typeof summary?.configured, 'boolean');
        assert.ok(summary?.fallback);
    }

    assert.doesNotMatch(JSON.stringify(configuration), /AIza|sk_|api_secret|service_role|password/i);
});

test('provider health contains no duplicate providers (one row per provider)', async () => {
    const health = await providerHealth();
    const names = health.map((item) => item.provider);
    const duplicates = names.filter((name, index) => names.indexOf(name) !== index);
    assert.deepEqual(duplicates, [], `duplicate provider health rows: ${duplicates.join(', ')}`);
});

test('provider statuses are internally consistent (no UNAVAILABLE+READY, no DISABLED rows claiming readiness)', async () => {
    const health = await providerHealth();
    for (const item of health) {
        // ENABLED/CONNECTED mean ready; UNAVAILABLE means a real failure and
        // must never be paired with readiness READY as the old model did.
        if (item.status === 'UNAVAILABLE') {
            assert.notEqual(item.readiness, 'READY', `${item.provider}: UNAVAILABLE + READY is contradictory`);
        }
        if (item.status === 'DISABLED') {
            assert.equal(item.readiness, 'DISABLED', `${item.provider}: DISABLED must not claim readiness`);
        }
        if (item.status === 'ENABLED' || item.status === 'CONNECTED') {
            assert.equal(item.readiness, 'READY', `${item.provider}: ${item.status} must be READY`);
        }
    }
});

test('disabled providers (clerk, twilio, aws) stay honestly disabled', async () => {
    const health = await providerHealth();
    const byName = new Map(health.map((item) => [item.provider, item]));
    for (const name of ['twilio', 'aws']) {
        const item = byName.get(name);
        if (item && !item.enabled) {
            assert.equal(item.status, 'DISABLED');
        }
    }
    const clerk = byName.get('clerk');
    if (clerk && !clerk.enabled) {
        assert.equal(clerk.status, 'DISABLED');
    }
});

test('existing PayMuster auth remains authoritative and passkeys stay unavailable', async () => {
    const capabilities = await authProvider.capabilities();
    assert.equal(capabilities.provider, 'paymuster');
    assert.equal(capabilities.password, true);
    assert.equal(capabilities.sessionRevocation, true);
    assert.equal(capabilities.passkeys, false);
});
