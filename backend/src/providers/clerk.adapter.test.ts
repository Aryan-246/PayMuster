import assert from 'node:assert/strict';
import test from 'node:test';

import { ClerkAdapter } from './clerk.adapter.js';

test('Clerk adapter remains a non-disruptive optional capability boundary', async () => {
    const adapter = new ClerkAdapter();
    const capabilities = await adapter.capabilities();
    const health = await adapter.health();

    assert.equal(capabilities.provider, 'clerk');
    assert.equal(capabilities.passkeys, false);
    assert.equal(capabilities.sessionRevocation, false);
    assert.ok(['DISABLED', 'INVALID_CONFIGURATION'].includes(health.status));
    assert.equal(health.fallback, 'paymuster-auth');
});
