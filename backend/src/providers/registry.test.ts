import assert from 'node:assert/strict';
import test from 'node:test';

import { providerHealth, redactProviderConfiguration, authProvider } from './registry.js';

test('provider registry reports safe disabled or configured states without secrets', async () => {
    const health = await providerHealth();
    assert.ok(health.length >= 6);
    for (const item of health) {
        assert.ok(['CONNECTED', 'DISABLED', 'INVALID_CONFIGURATION', 'RATE_LIMITED', 'UNAVAILABLE'].includes(item.status));
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

test('existing PayMuster auth remains authoritative and passkeys stay unavailable', async () => {
    const capabilities = await authProvider.capabilities();
    assert.equal(capabilities.provider, 'paymuster');
    assert.equal(capabilities.password, true);
    assert.equal(capabilities.sessionRevocation, true);
    assert.equal(capabilities.passkeys, false);
});
