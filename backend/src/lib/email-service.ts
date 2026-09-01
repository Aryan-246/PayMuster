import nodemailer, { type Transporter } from 'nodemailer';
import type SMTPTransport from 'nodemailer/lib/smtp-transport/index.js';
import { AppError } from './app-error.js';
import { config } from './config.js';
import { logger, maskEmail } from './logger.js';
import type { EmailMessage, EmailProvider, ProviderHealth } from '../providers/contracts.js';
import { getProviderUse, recordProviderFailure, recordProviderSuccess } from '../providers/usage-tracker.js';

export interface EmailTemplateData {
  name?: string;
  otp?: string;
  deviceName?: string;
  browserName?: string;
  ipAddress?: string;
  timestamp?: string;
}

type EmailTemplate =
  | 'verification'
  | 'password-reset'
  | 'welcome'
  | 'password-changed'
  | 'login-alert'
  | 'google-login'
  | 'account-deletion';

interface RenderedEmail {
  html: string;
  text: string;
}

const MAX_RETRY_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 1_000;

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function displayName(name?: string): string {
  return escapeHtml(name?.trim() || 'there');
}

function formatTimestamp(ts?: string): string {
  if (!ts) {
    return new Date().toLocaleString('en-US', {
      dateStyle: 'long',
      timeStyle: 'short',
      timeZone: 'Asia/Kolkata',
    });
  }
  return escapeHtml(ts);
}

function otpBlock(otp: string): string {
  const digits = otp.split('');
  const digitCells = digits
    .map(
      (d) =>
        '<td style="width:48px;height:56px;background:#1a2332;border:2px solid #15D1C2;border-radius:12px;text-align:center;vertical-align:middle;font-family:\'Courier New\',monospace;font-size:28px;font-weight:800;color:#15D1C2;letter-spacing:2px;">' +
        escapeHtml(d) +
        '</td>',
    )
    .join('<td style="width:8px;"></td>');

  return [
    '<div style="margin:28px 0;text-align:center;">',
    '<p style="margin:0 0 14px;color:#8B95A5;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">Your secure code</p>',
    '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 auto;">',
    '<tr>' + digitCells + '</tr>',
    '</table>',
    '<p style="margin:14px 0 0;color:#5C6575;font-size:12px;">Expires in 10 minutes • Single use only</p>',
    '</div>',
  ].join('');
}

function contextBlock(data: EmailTemplateData): string {
  const rows: string[] = [];

  if (data.timestamp) {
    rows.push(contextRow('Time', formatTimestamp(data.timestamp)));
  }

  if (data.browserName) {
    rows.push(contextRow('Browser', escapeHtml(data.browserName)));
  }

  if (data.deviceName) {
    rows.push(contextRow('Device', escapeHtml(data.deviceName)));
  }

  if (data.ipAddress) {
    rows.push(contextRow('IP Address', escapeHtml(data.ipAddress)));
  }

  if (rows.length === 0) {
    return '';
  }

  return [
    '<div style="margin:20px 0;background:#111827;border:1px solid #1E293B;border-radius:10px;padding:16px;overflow:hidden;">',
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="font-size:13px;">',
    rows.join(''),
    '</table>',
    '</div>',
  ].join('');
}

function contextRow(label: string, value: string): string {
  return (
    '<tr>' +
    '<td style="padding:5px 12px 5px 0;color:#8B95A5;font-weight:600;white-space:nowrap;">' +
    escapeHtml(label) +
    '</td>' +
    '<td style="padding:5px 0;color:#E2E8F0;">' +
    value +
    '</td>' +
    '</tr>'
  );
}

function renderLayout(options: {
  title: string;
  preview: string;
  body: string;
  textBody: string;
  otp?: string;
  data?: EmailTemplateData;
  ignoreText: string;
  footerNote?: string;
}): RenderedEmail {
  const securityNotice =
    'PayMuster will never ask for your password or verification code by phone, chat, or email reply.';
  const supportEmail = escapeHtml(config.emailSupport);
  const footerNote = options.footerNote || 'This is an automated security notification for your PayMuster account.';
  const year = String(new Date().getFullYear());

  const html = [
    '<!doctype html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<meta name="x-apple-disable-message-reformatting">',
    '<meta name="color-scheme" content="dark">',
    '<meta name="supported-color-schemes" content="dark">',
    '<title>',
    escapeHtml(options.title),
    '</title>',
    '<style>',
    ':root{color-scheme:dark}',
    '@media only screen and (max-width:620px){.pm-shell{padding:12px!important}.pm-card{border-radius:14px!important;padding:24px!important}.pm-title{font-size:22px!important}}',
    '</style>',
    '</head>',
    '<body style="margin:0;padding:0;background:#0B1117;color:#E2E8F0;font-family:\'Segoe UI\',Inter,Arial,sans-serif;-webkit-font-smoothing:antialiased;">',
    // Preview text
    '<span style="display:none!important;visibility:hidden;mso-hide:all;font-size:1px;color:#0B1117;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">',
    escapeHtml(options.preview),
    '</span>',
    // Outer table
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;background:#0B1117;">',
    '<tr><td class="pm-shell" style="padding:32px 16px;">',
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;max-width:560px;margin:0 auto;">',
    // Logo row
    '<tr><td style="padding:0 0 24px;">',
    '<table role="presentation" cellspacing="0" cellpadding="0"><tr>',
    '<td style="width:36px;height:36px;background:linear-gradient(135deg,#0E7C86,#15D1C2);border-radius:10px;text-align:center;vertical-align:middle;">',
    '<span style="font-size:18px;font-weight:900;color:#fff;line-height:36px;">P</span>',
    '</td>',
    '<td style="padding-left:10px;color:#F0F0F0;font-size:18px;font-weight:800;letter-spacing:-0.3px;">PayMuster</td>',
    '</tr></table>',
    '</td></tr>',
    // Card
    '<tr><td class="pm-card" style="background:#161B22;border:1px solid #1E293B;border-radius:16px;padding:36px;">',
    // Category label
    '<p style="margin:0 0 8px;color:#15D1C2;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">Account Security</p>',
    // Title
    '<h1 class="pm-title" style="margin:0 0 20px;color:#F0F0F0;font-size:26px;line-height:1.25;letter-spacing:-0.5px;font-weight:700;">',
    escapeHtml(options.title),
    '</h1>',
    // Body
    '<div style="color:#CBD5E1;font-size:15px;line-height:1.65;">',
    options.body,
    '</div>',
    // OTP block
    options.otp ? otpBlock(options.otp) : '',
    // Context block (IP, browser, time)
    options.data ? contextBlock(options.data) : '',
    // Security notice
    '<div style="margin-top:24px;padding:14px 16px;border-left:3px solid #15D1C2;background:#0D2E31;border-radius:0 8px 8px 0;color:#7EEAE0;font-size:13px;line-height:1.5;">',
    '<strong>Security notice:</strong> ',
    escapeHtml(securityNotice),
    '</div>',
    // Ignore text
    '<p style="margin:18px 0 0;color:#5C6575;font-size:12px;line-height:1.5;">',
    escapeHtml(options.ignoreText),
    '</p>',
    '</td></tr>',
    // Footer
    '<tr><td style="padding:24px 0 0;text-align:center;">',
    '<p style="margin:0 0 6px;color:#5C6575;font-size:12px;line-height:1.5;">',
    escapeHtml(footerNote),
    '</p>',
    '<p style="margin:0 0 6px;color:#5C6575;font-size:12px;">',
    'Need help? <a href="mailto:',
    supportEmail,
    '" style="color:#15D1C2;text-decoration:none;">',
    supportEmail,
    '</a>',
    '</p>',
    '<p style="margin:0;color:#3D4654;font-size:11px;">',
    '&copy; ',
    year,
    ' PayMuster &middot; Secure workforce operations',
    '</p>',
    '</td></tr>',
    '</table>',
    '</td></tr></table>',
    '</body></html>',
  ].join('');

  const text = [
    options.textBody,
    '',
    'Security notice: ' + securityNotice,
    footerNote,
    options.ignoreText,
    '',
    'Support: ' + config.emailSupport,
    '© ' + year + ' PayMuster',
  ].join('\n');

  return { html, text };
}

function renderTemplate(template: EmailTemplate, data: EmailTemplateData): RenderedEmail {
  const name = displayName(data.name);
  const timestamp = formatTimestamp(data.timestamp);

  switch (template) {
    case 'verification':
      return renderLayout({
        title: 'Verify your email address',
        preview: 'Your PayMuster verification code: ' + (data.otp || ''),
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">Welcome to PayMuster! Enter the code below to verify your email and activate your account.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nWelcome to PayMuster! Verify your email with this code: ' +
          (data.otp || ''),
        otp: data.otp,
        ignoreText: 'If you did not create a PayMuster account, you can safely ignore this email.',
      });

    case 'password-reset':
      return renderLayout({
        title: 'Reset your password',
        preview: 'Your PayMuster password reset code: ' + (data.otp || ''),
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">We received a request to reset your PayMuster password. Enter the code below to choose a new password.</p>' +
          '<p style="margin:14px 0 0;color:#EF4444;font-weight:600;font-size:13px;">⚠ If you did not request this, your account may be at risk. Change your password immediately.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nUse this code to reset your PayMuster password: ' +
          (data.otp || '') +
          '\n\nIf you did not request this, your account may be at risk.',
        otp: data.otp,
        data,
        ignoreText:
          'If you did not request a password reset, change your password immediately and contact support.',
      });

    case 'welcome':
      return renderLayout({
        title: 'Welcome to PayMuster!',
        preview: 'Your PayMuster account is verified and ready.',
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">Your email has been verified and your account is now fully active. Welcome aboard — we\'re glad to have you with us.</p>' +
          '<p style="margin:14px 0 0;">You can now sign in and start managing your workforce operations.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nYour email is verified and your PayMuster account is ready. Welcome aboard!',
        ignoreText: 'If you did not create this account, contact our support team immediately.',
      });

    case 'password-changed':
      return renderLayout({
        title: 'Your password was changed',
        preview: 'Your PayMuster password has been updated.',
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">Your PayMuster password was changed successfully at <strong>' +
          timestamp +
          '</strong>.</p>' +
          '<p style="margin:14px 0 0;">You can now sign in with your new password. All existing sessions have been revoked for security.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nYour PayMuster password was changed at ' +
          timestamp +
          '.',
        data,
        ignoreText:
          'If you did not make this change, reset your password immediately and contact support.',
      });

    case 'login-alert':
      return renderLayout({
        title: 'New sign-in to your account',
        preview: 'A new sign-in to your PayMuster account was detected.',
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">A successful sign-in to your PayMuster account was detected at <strong>' +
          timestamp +
          '</strong>.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nA sign-in to your PayMuster account was detected at ' +
          timestamp +
          '.',
        data,
        ignoreText: 'If this was not you, reset your password immediately and contact support.',
      });

    case 'google-login':
      return renderLayout({
        title: 'Google sign-in detected',
        preview: 'A Google sign-in to your PayMuster account was detected.',
        body:
          '<p style="margin:0;">Hi ' +
          name +
          ',</p>' +
          '<p style="margin:14px 0 0;">Your PayMuster account was accessed using Google Sign-In at <strong>' +
          timestamp +
          '</strong>.</p>',
        textBody:
          'Hi ' +
          (data.name || 'there') +
          ',\n\nYour PayMuster account was accessed via Google Sign-In at ' +
          timestamp +
          '.',
        data,
        ignoreText: 'If this was not you, contact support immediately to secure your account.',
      });
    case 'account-deletion':
      return renderLayout({
        title: '⚠️ Permanent Account Deletion Verification',
        preview: 'WARNING: Someone requested permanent deletion of your PayMuster account.',
        body:
          '<p style="margin:0;"><strong>WARNING</strong></p>' +
          '<p style="margin:14px 0 0;">Someone requested permanent deletion of your PayMuster account.</p>' +
          '<p style="margin:14px 0 0;">After deletion:</p>' +
          '<ul style="margin:14px 0 0; padding-left:20px;">' +
          '<li>Account cannot be recovered</li>' +
          '<li>Sessions will be revoked</li>' +
          '<li>Company ownership may be removed</li>' +
          '<li>This action is irreversible</li>' +
          '</ul>' +
          '<p style="margin:14px 0 0;">OTP<br><strong style="font-size:24px;">' + (data.otp || '') + '</strong></p>' +
          '<p style="margin:14px 0 0;">Expires in 5 minutes.</p>',
        textBody:
          'WARNING\n\n' +
          'Someone requested permanent deletion of your PayMuster account.\n\n' +
          'After deletion:\n' +
          '• Account cannot be recovered\n' +
          '• Sessions will be revoked\n' +
          '• Company ownership may be removed\n' +
          '• This action is irreversible\n\n' +
          'OTP\n' +
          (data.otp || '') + '\n\n' +
          'Expires in 5 minutes.',
        data,
        ignoreText: 'If this wasn\'t you, ignore this email.',
      });
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export interface EmailServiceOptions {
  transporter?: Pick<Transporter, 'sendMail' | 'verify'> | null;
  enabled?: boolean;
  emailFrom?: string;
  sleep?: (milliseconds: number) => Promise<void>;
}

function parseBrowserName(userAgent?: string): string {
  if (!userAgent) return 'Unknown browser';
  if (userAgent.includes('Edg/')) return 'Microsoft Edge';
  if (userAgent.includes('Chrome/') && !userAgent.includes('Edg/')) return 'Google Chrome';
  if (userAgent.includes('Firefox/')) return 'Mozilla Firefox';
  if (userAgent.includes('Safari/') && !userAgent.includes('Chrome/')) return 'Safari';
  if (userAgent.includes('Opera/') || userAgent.includes('OPR/')) return 'Opera';
  if (userAgent.includes('Dart/')) return 'PayMuster App';
  return 'Unknown browser';
}

export class EmailService {
  private readonly transporter: Pick<Transporter, 'sendMail' | 'verify'> | null;
  private readonly enabled: boolean;
  private readonly emailFrom: string;
  private readonly sleep: (milliseconds: number) => Promise<void>;

  constructor(options: EmailServiceOptions = {}) {
    this.enabled = options.enabled ?? config.smtpEnabled;
    this.emailFrom = options.emailFrom ?? config.emailFrom;
    this.sleep = options.sleep ?? sleep;
    this.transporter = options.transporter !== undefined
      ? options.transporter
      : this.enabled && config.emailUser && config.emailAppPassword
        ? nodemailer.createTransport({
          host: config.smtpHost,
          port: config.smtpPort,
          secure: config.smtpSecure,
          auth: {
            user: config.emailUser,
            pass: config.emailAppPassword,
          },
          pool: true,
          maxConnections: 5,
          maxMessages: 100,
          connectionTimeout: 10_000,
          greetingTimeout: 10_000,
          socketTimeout: 20_000,
          tls: { minVersion: 'TLSv1.2' },
        })
        : null;
  }

  get isConfigured(): boolean {
    return this.transporter !== null && Boolean(this.emailFrom);
  }

  async health(): Promise<ProviderHealth> {
    const configured = this.isConfigured;
    if (!this.enabled) {
      return {
        provider: 'smtp',
        kind: 'EMAIL',
        status: 'DISABLED',
        readiness: 'DISABLED',
        enabled: false,
        fallback: 'in-app-notification',
        checkedAt: new Date().toISOString(),
        detail: 'Email delivery is optional and remains non-transaction-critical.',
      };
    }
    if (!configured) {
      return {
        provider: 'smtp',
        kind: 'EMAIL',
        status: 'INVALID_CONFIGURATION',
        readiness: 'MISSING_CONFIGURATION',
        enabled: true,
        fallback: 'in-app-notification',
        checkedAt: new Date().toISOString(),
        detail: 'SMTP is enabled but not configured.',
      };
    }
    // Live-verified delivery: the usage tracker records every real send.
    const use = getProviderUse('smtp');
    if (use && use.successCount > 0) {
      return {
        provider: 'smtp',
        kind: 'EMAIL',
        status: 'CONNECTED',
        readiness: 'READY',
        enabled: true,
        fallback: 'in-app-notification',
        checkedAt: new Date().toISOString(),
        detail: `SMTP has delivered ${use.successCount} message(s) live; last delivery ${use.lastSuccessAt.toISOString()}.`,
      };
    }
    if (use && use.failureCount > 0 && use.successCount === 0) {
      return {
        provider: 'smtp',
        kind: 'EMAIL',
        status: 'UNAVAILABLE',
        readiness: 'READY',
        enabled: true,
        fallback: 'in-app-notification',
        checkedAt: new Date().toISOString(),
        detail: `SMTP is configured but every delivery attempt so far has failed; last error: ${use.lastError ?? 'unknown'}.`,
      };
    }
    return {
      provider: 'smtp',
      kind: 'EMAIL',
      status: 'ENABLED',
      readiness: 'READY',
      enabled: true,
      fallback: 'in-app-notification',
      checkedAt: new Date().toISOString(),
      detail: 'SMTP is configured; message delivery is verified per send attempt.',
    };
  }

  async send(message: EmailMessage): Promise<'SENT' | 'SKIPPED' | 'UNAVAILABLE'> {
    if (!this.enabled || !this.transporter || !this.emailFrom) {
      logger.warn('email.provider_skipped', {
        eventId: message.eventId,
        recipient: maskEmail(message.to),
        reason: 'SMTP_NOT_CONFIGURED',
      });
      return 'SKIPPED';
    }

    let lastError: unknown = null;
    for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
      try {
        const result: SMTPTransport.SentMessageInfo = await this.transporter.sendMail({
          from: this.emailFrom,
          to: message.to,
          subject: message.subject,
          html: message.html,
          text: message.text,
          headers: { 'X-PayMuster-Event-Id': message.eventId },
        });
        recordProviderSuccess('smtp');
        logger.info('email.provider_sent', {
          eventId: message.eventId,
          recipient: maskEmail(message.to),
          messageId: result.messageId,
          attempt,
        });
        return 'SENT';
      } catch (error) {
        lastError = error;
        logger.error('email.provider_send_attempt_failed', error, {
          eventId: message.eventId,
          recipient: maskEmail(message.to),
          attempt,
          maxAttempts: MAX_RETRY_ATTEMPTS,
        });
        if (attempt < MAX_RETRY_ATTEMPTS) {
          await this.sleep(INITIAL_RETRY_DELAY_MS * Math.pow(2, attempt - 1));
        }
      }
    }

    recordProviderFailure('smtp', lastError instanceof Error ? lastError.message : String(lastError));
    logger.error('email.provider_unavailable', lastError, {
      eventId: message.eventId,
      recipient: maskEmail(message.to),
      totalAttempts: MAX_RETRY_ATTEMPTS,
    });
    return 'UNAVAILABLE';
  }

  async verifyConnection(): Promise<boolean> {
    if (!this.enabled || !this.transporter) {
      logger.warn('email.smtp_not_configured');
      return false;
    }

    try {
      await this.transporter.verify();
      logger.info('email.smtp_ready', {
        host: config.smtpHost,
        port: config.smtpPort,
        note: 'SMTP connectivity verified. This does NOT guarantee message delivery.',
      });
      return true;
    } catch (error) {
      logger.error('email.smtp_unavailable', error, {
        host: config.smtpHost,
        port: config.smtpPort,
      });
      return false;
    }
  }

  async sendVerificationEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('verification', to, 'Verify your PayMuster account', data);
  }

  async sendAccountCreatedNotification(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendVerificationEmail(to, data);
  }

  async sendAccountDeletionEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('account-deletion', to, '⚠️ Permanent Account Deletion Verification', data);
  }

  async sendPasswordResetEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('password-reset', to, 'Reset your PayMuster password', data);
  }

  async sendWelcomeEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('welcome', to, 'Welcome to PayMuster!', data);
  }

  async sendPasswordChangedEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('password-changed', to, 'Your PayMuster password was changed', data);
  }

  async sendLoginNotificationEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('login-alert', to, 'New sign-in to PayMuster', data);
  }

  async sendGoogleLoginNotificationEmail(to: string, data: EmailTemplateData): Promise<void> {
    await this.sendTemplate('google-login', to, 'Google sign-in to PayMuster', data);
  }

  static parseBrowserName(userAgent?: string): string {
    return parseBrowserName(userAgent);
  }

  private async sendTemplate(
    template: EmailTemplate,
    to: string,
    subject: string,
    data: EmailTemplateData,
  ): Promise<void> {
    if (!this.enabled || !this.transporter || !this.emailFrom) {
      throw new AppError(
        'EMAIL_NOT_CONFIGURED',
        'Email delivery is not configured. Please contact support.',
        503,
      );
    }

    const rendered = renderTemplate(template, data);
    const startTime = Date.now();
    let lastError: unknown = null;

    for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
      try {
        const result: SMTPTransport.SentMessageInfo = await this.transporter.sendMail({
          from: this.emailFrom,
          to,
          subject,
          html: rendered.html,
          text: rendered.text,
        });

        const elapsedMs = Date.now() - startTime;

        logger.info('email.sent', {
          template,
          recipient: maskEmail(to),
          subject,
          messageId: result.messageId,
          smtpResponse: result.response,
          accepted: result.accepted,
          rejected: result.rejected,
          elapsedMs,
          attempt,
        });

        return;
      } catch (error) {
        lastError = error;
        const elapsedMs = Date.now() - startTime;

        logger.error('email.send_attempt_failed', error, {
          template,
          recipient: maskEmail(to),
          subject,
          attempt,
          maxAttempts: MAX_RETRY_ATTEMPTS,
          elapsedMs,
        });

        if (attempt < MAX_RETRY_ATTEMPTS) {
          const delayMs = INITIAL_RETRY_DELAY_MS * Math.pow(2, attempt - 1);
          await this.sleep(delayMs);
        }
      }
    }

    const totalElapsedMs = Date.now() - startTime;
    logger.error('email.delivery_failed_all_retries', lastError, {
      template,
      recipient: maskEmail(to),
      subject,
      totalAttempts: MAX_RETRY_ATTEMPTS,
      totalElapsedMs,
    });

    throw new AppError(
      'EMAIL_DELIVERY_FAILED',
      'We could not deliver the email after multiple attempts. Please try again.',
      503,
    );
  }
}

export const emailService = new EmailService();
