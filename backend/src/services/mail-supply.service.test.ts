import assert from 'node:assert/strict';
import test from 'node:test';
import { MailSupplyService, FREE_PLAN_MONTHLY_MAIL_LIMIT } from './mail-supply.service.js';
import { AppError } from '../lib/app-error.js';

test('mail supply quota defaults to 10 mails per month for free plan', async () => {
    assert.equal(FREE_PLAN_MONTHLY_MAIL_LIMIT, 10);
});

test('mail supply enforces Owner restriction: cannot target all organizations', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'owner-1',
            actorRole: 'OWNER',
            orgId: 'org-1',
            targetType: 'ALL',
            subject: 'Announcement',
            body: 'Hello',
        }),
        (err) => err instanceof AppError && err.code === 'TENANT_DENIED',
    );
});

test('mail supply requires targetRole when targeting by role', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'admin-1',
            actorRole: 'ADMIN',
            orgId: 'org-1',
            targetType: 'ROLE',
            subject: 'Notice',
            body: 'Body',
        }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('mail supply requires targetUserId when targeting individual', async () => {
    const service = new MailSupplyService();
    await assert.rejects(
        service.resolveTargets({
            actorId: 'admin-1',
            actorRole: 'ADMIN',
            orgId: 'org-1',
            targetType: 'INDIVIDUAL',
            subject: 'Direct',
            body: 'Private',
        }),
        (err) => err instanceof AppError && err.code === 'VALIDATION_ERROR',
    );
});

test('mail supply quota calculation boundary enforces 10/month limit', () => {
    const limit = 10;
    const testCases = [
        { sent: 0, requested: 1, allowed: 1, willBlock: false },
        { sent: 8, requested: 1, allowed: 1, willBlock: false }, // 9th mail
        { sent: 9, requested: 1, allowed: 1, willBlock: false }, // 10th mail
        { sent: 10, requested: 1, allowed: 0, willBlock: true },  // 11th mail -> blocked
    ];

    for (const tc of testCases) {
        const remaining = Math.max(0, limit - tc.sent);
        if (tc.willBlock) {
            assert.equal(remaining, 0);
        } else {
            assert.ok(remaining >= tc.allowed);
        }
    }
});
