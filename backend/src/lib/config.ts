import crypto from 'node:crypto';
import dotenv from 'dotenv';

dotenv.config();

const defaultOrigins = ['http://localhost:5173', 'http://localhost:3000', 'http://localhost:7357'];
const nodeEnv = process.env.NODE_ENV ?? 'development';

function parsePositiveInteger(name: string, value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(name + ' must be a positive integer.');
  }

  return parsed;
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }

  return value.toLowerCase() === 'true';
}

function parseDuration(value: string, fallbackMs: number): number {
  const match = /^(\d+)(s|m|h|d)$/.exec(value.trim());
  if (!match) {
    return fallbackMs;
  }

  const amount = Number(match[1]);
  const unit = match[2];
  const multipliers: Record<string, number> = {
    s: 1_000,
    m: 60_000,
    h: 3_600_000,
    d: 86_400_000,
  };

  return amount * multipliers[unit];
}

const configuredJwtSecret = process.env.JWT_SECRET?.trim();
if (nodeEnv === 'production' && (!configuredJwtSecret || configuredJwtSecret.length < 32)) {
  throw new Error('JWT_SECRET must be at least 32 characters in production.');
}

const jwtSecret = configuredJwtSecret || crypto.randomBytes(48).toString('base64url');
const emailUser = process.env.EMAIL_USER?.trim() ?? '';
const appUrl = (process.env.APP_URL ?? 'http://localhost:5173').replace(/\/$/, '');
const jwtAccessExpiresIn = process.env.JWT_ACCESS_EXPIRES_IN ?? '15m';
const jwtRefreshExpiresIn = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';

export const config = Object.freeze({
  nodeEnv,
  port: parsePositiveInteger('PORT', process.env.PORT, 4000),
  appUrl,
  databaseUrl: process.env.DATABASE_URL ?? '',
  jwtSecret,
  jwtIssuer: process.env.JWT_ISSUER?.trim() || 'paymuster-api',
  jwtAudience: process.env.JWT_AUDIENCE?.trim() || 'paymuster-client',
  jwtAccessExpiresIn,
  jwtRefreshExpiresIn,
  jwtAccessTtlMs: parseDuration(jwtAccessExpiresIn, 15 * 60_000),
  rememberMeSessionMs: parseDuration(process.env.SESSION_REMEMBER_ME_EXPIRES_IN ?? jwtRefreshExpiresIn, 30 * 24 * 60 * 60_000),
  standardSessionMs: parseDuration(process.env.SESSION_EXPIRES_IN ?? '7d', 7 * 24 * 60 * 60_000),
  otpHashSecret: process.env.OTP_HASH_SECRET?.trim() || jwtSecret,
  otpExpiresInMs: 10 * 60_000,
  otpResendCooldownMs: 60_000,
  otpMaxResendAttempts: parsePositiveInteger('OTP_MAX_RESEND_ATTEMPTS', process.env.OTP_MAX_RESEND_ATTEMPTS, 5),
  otpMaxVerificationAttempts: parsePositiveInteger('OTP_MAX_VERIFICATION_ATTEMPTS', process.env.OTP_MAX_VERIFICATION_ATTEMPTS, 5),
  emailUser,
  emailAppPassword: process.env.EMAIL_APP_PASSWORD ?? '',
  emailFrom: process.env.EMAIL_FROM?.trim() || (emailUser ? 'PayMuster <' + emailUser + '>' : ''),
  emailSupport: process.env.SUPPORT_EMAIL?.trim() || 'support@paymuster.com',
  emailLogoUrl: process.env.EMAIL_LOGO_URL?.trim() || appUrl + '/paymuster_logo.png',
  smtpHost: process.env.SMTP_HOST?.trim() || 'smtp.gmail.com',
  smtpPort: parsePositiveInteger('SMTP_PORT', process.env.SMTP_PORT, 465),
  smtpSecure: parseBoolean(process.env.SMTP_SECURE, true),
  googleClientId: process.env.GOOGLE_WEB_CLIENT_ID ?? process.env.GOOGLE_ANDROID_CLIENT_ID ?? '',
  corsOrigins: (process.env.CORS_ORIGINS ?? defaultOrigins.join(','))
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
});
