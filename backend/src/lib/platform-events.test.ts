import assert from 'node:assert/strict';
import test from 'node:test';

import { PlatformEventName, createPlatformEvent } from './platform-events.js';

test('platform events are uniquely identified and carry organization-aware context', () => {
    const first = createPlatformEvent(
        PlatformEventName.DOCUMENT_UPLOADED,
        { documentId: 'doc-1', status: 'PENDING_REVIEW' },
        { actorId: 'user-1', orgId: 'org-1', targetId: 'staff-1' },
    );
    const second = createPlatformEvent(PlatformEventName.DOCUMENT_UPLOADED, { documentId: 'doc-2' });

    assert.notEqual(first.id, second.id);
    assert.equal(first.name, 'DOCUMENT_UPLOADED');
    assert.equal(first.orgId, 'org-1');
    assert.equal(first.targetId, 'staff-1');
    assert.equal(first.payload.status, 'PENDING_REVIEW');
    assert.match(first.occurredAt, /^20\d\d-/);
});

test('platform event payloads do not receive credentials by construction', () => {
    const event = createPlatformEvent(PlatformEventName.AI_ANALYSIS_COMPLETED, {
        provider: 'gemini',
        status: 'COMPLETED',
        secret: undefined,
    });
    assert.doesNotMatch(JSON.stringify(event), /AIza|sk_|service_role|password|refreshToken/i);
});
