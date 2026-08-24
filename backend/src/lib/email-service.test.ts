import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from './app-error.js';
import { EmailService } from './email-service.js';

const email = {
    eventId: 'email-event-id',
    to: 'worker@example.com',
    subject: 'Test notification',
    text: 'Plain text body',
    html: '<p>HTML body</p>',
};

function fakeTransport(sendMail: (message: Record<string, unknown>) => Promise<{ messageId: string }>) {
    return {
        sendMail,
        verify: async (): Promise<true> => true,
    };
}

test('email provider skips delivery when SMTP is disabled', async () => {
    let calls = 0;
    const service = new EmailService({
        enabled: false,
        emailFrom: 'PayMuster <noreply@example.com>',
        transporter: fakeTransport(async () => {
            calls += 1;
            return { messageId: 'should-not-send' };
        }),
    });

    assert.equal(await service.send(email), 'SKIPPED');
    assert.equal(calls, 0);
    assert.equal((await service.health()).readiness, 'DISABLED');
});

test('email provider sends the message with a correlation event header', async () => {
    let sentMessage: Record<string, unknown> | undefined;
    const service = new EmailService({
        enabled: true,
        emailFrom: 'PayMuster <noreply@example.com>',
        transporter: fakeTransport(async (message) => {
            sentMessage = message;
            return { messageId: 'smtp-message-id' };
        }),
    });

    assert.equal(await service.send(email), 'SENT');
    assert.equal(sentMessage?.to, email.to);
    assert.equal(sentMessage?.from, 'PayMuster <noreply@example.com>');
    assert.deepEqual(sentMessage?.headers, { 'X-PayMuster-Event-Id': email.eventId });
});

test('email provider retries transient transport failures and returns unavailable after exhaustion', async () => {
    let calls = 0;
    const waits: number[] = [];
    const service = new EmailService({
        enabled: true,
        emailFrom: 'PayMuster <noreply@example.com>',
        sleep: async (milliseconds) => {
            waits.push(milliseconds);
        },
        transporter: fakeTransport(async () => {
            calls += 1;
            throw new Error('SMTP connection refused');
        }),
    });

    assert.equal(await service.send(email), 'UNAVAILABLE');
    assert.equal(calls, 3);
    assert.deepEqual(waits, [1000, 2000]);
});

test('security templates escape user content and render both HTML and text bodies', async () => {
    let sentMessage: Record<string, unknown> | undefined;
    const service = new EmailService({
        enabled: true,
        emailFrom: 'PayMuster <noreply@example.com>',
        transporter: fakeTransport(async (message) => {
            sentMessage = message;
            return { messageId: 'smtp-message-id' };
        }),
    });

    await service.sendVerificationEmail('worker@example.com', { name: '<script>alert(1)</script>', otp: '123456' });
    const html = String(sentMessage?.html);
    assert.ok(html.includes(String.fromCharCode(38) + 'lt;script' + String.fromCharCode(38) + 'gt;alert(1)' + String.fromCharCode(38) + 'lt;/script' + String.fromCharCode(38) + 'gt;'));
    assert.ok(!html.includes(String.fromCharCode(60) + 'script>alert(1)' + String.fromCharCode(60) + '/script' + String.fromCharCode(62)));
    assert.match(html, /123456/);
    assert.match(String(sentMessage?.text), /123456/);
});

test('required security templates fail explicitly when SMTP is unavailable', async () => {
    const service = new EmailService({ enabled: false, transporter: null });

    await assert.rejects(
        service.sendPasswordResetEmail('worker@example.com', { otp: '123456' }),
        (error: unknown) => error instanceof AppError && error.code === 'EMAIL_NOT_CONFIGURED' && error.status === 503,
    );
});
