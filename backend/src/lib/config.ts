import crypto from 'node:crypto';
import dotenv from 'dotenv';
import type { ProviderConfigurationSummary, ProviderKind, ProviderReadiness } from '../providers/contracts.js';

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
// MIME types the document allowlist is permitted to reference. Office formats
// are recognized here so they can be turned on via an explicit allowlist, but
// they are intentionally NOT part of the default set (extend only on purpose).
const knownDocumentMimeTypes = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
  'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
  'application/msword', // .doc
  'application/vnd.ms-excel', // .xls
  'application/vnd.ms-powerpoint', // .ppt
]);
const defaultDocumentMimeTypes = ['application/pdf', 'image/jpeg', 'image/png'];
const documentAllowedMimeTypes = (process.env.DOCUMENT_ALLOWED_MIME_TYPES ??
  defaultDocumentMimeTypes.join(','))
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);

if (
  documentAllowedMimeTypes.length === 0 ||
  documentAllowedMimeTypes.some((value) => !knownDocumentMimeTypes.has(value))
) {
  throw new Error(
    'DOCUMENT_ALLOWED_MIME_TYPES must contain only supported document formats (PDF, JPEG, PNG, or Office documents).',
  );
}

const razorpayMode = process.env.RAZORPAY_MODE?.trim().toLowerCase() || 'test';
if (razorpayMode !== 'test' && razorpayMode !== 'live') {
  throw new Error('RAZORPAY_MODE must be either test or live.');
}

const firebasePrivateKey = (process.env.FIREBASE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n').trim();

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
  geminiApiKey: process.env.GEMINI_API_KEY?.trim(),
  geminiModel: process.env.GEMINI_MODEL?.trim() || 'gemini-3.6-flash',
  geminiEnabled: parseBoolean(process.env.AI_ENABLED, Boolean(process.env.GEMINI_API_KEY?.trim())),
  // Per-call Gemini budget. Measured round-trip latency from this deployment
  // to the Gemini API varies from ~3.5s to ~35s for a minimal prompt, so a
  // 15s budget timed out most requests ("AI analysis timed out"). 60s covers
  // the observed worst case with headroom; each chat round is still bounded
  // individually and the overall deadline bounds the whole loop.
  geminiTimeoutMs: parsePositiveInteger(
    'GEMINI_TIMEOUT_MS',
    process.env.GEMINI_TIMEOUT_MS,
    60_000,
  ),
  // Overall budget for one admin AI chat request, covering every provider
  // round-trip and tool execution. The per-call timeout (geminiTimeoutMs)
  // bounds a single model call; this deadline bounds the whole agentic loop
  // so a multi-tool conversation can never run unbounded (3 rounds × per-call
  // budget + tool execution time).
  aiOverallDeadlineMs: parsePositiveInteger(
    'AI_OVERALL_DEADLINE_MS',
    process.env.AI_OVERALL_DEADLINE_MS,
    180_000,
  ),
  supabaseUrl: (process.env.SUPABASE_URL ?? '').trim().replace(/\/$/, ''),
  supabaseServiceRoleKey: (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim(),
  documentStorageBucket: (process.env.DOCUMENT_STORAGE_BUCKET ?? '').trim(),
  documentUploadMaxBytes: parsePositiveInteger(
    'DOCUMENT_UPLOAD_MAX_BYTES',
    process.env.DOCUMENT_UPLOAD_MAX_BYTES,
    10 * 1024 * 1024,
  ),
  documentSignedUrlTtlSeconds: parsePositiveInteger(
    'DOCUMENT_SIGNED_URL_TTL_SECONDS',
    process.env.DOCUMENT_SIGNED_URL_TTL_SECONDS,
    300,
  ),
  avatarUploadMaxBytes: parsePositiveInteger(
    'AVATAR_UPLOAD_MAX_BYTES',
    process.env.AVATAR_UPLOAD_MAX_BYTES,
    5 * 1024 * 1024,
  ),
  documentAllowedMimeTypes: Object.freeze(documentAllowedMimeTypes),
  // Per-category document size tiers in bytes: recommended "target", soft
  // "warn" (accepted but flagged), and hard "max" (rejected). All values are
  // env-configurable (no magic numbers); at use sites the effective hard cap
  // is additionally clamped to documentUploadMaxBytes (the 10 MB bucket max).
  // Audio/video are deliberately absent — they belong to a separate
  // media-private architecture, never the staff-documents-private bucket.
  documentSizePolicy: Object.freeze({
    image: Object.freeze({
      target: parsePositiveInteger('DOC_IMAGE_TARGET_BYTES', process.env.DOC_IMAGE_TARGET_BYTES, 512 * 1024),
      warn: parsePositiveInteger('DOC_IMAGE_WARN_BYTES', process.env.DOC_IMAGE_WARN_BYTES, 1024 * 1024),
      max: parsePositiveInteger('DOC_IMAGE_MAX_BYTES', process.env.DOC_IMAGE_MAX_BYTES, 5 * 1024 * 1024),
    }),
    pdf: Object.freeze({
      target: parsePositiveInteger('DOC_PDF_TARGET_BYTES', process.env.DOC_PDF_TARGET_BYTES, 2 * 1024 * 1024),
      warn: parsePositiveInteger('DOC_PDF_WARN_BYTES', process.env.DOC_PDF_WARN_BYTES, 5 * 1024 * 1024),
      max: parsePositiveInteger('DOC_PDF_MAX_BYTES', process.env.DOC_PDF_MAX_BYTES, 10 * 1024 * 1024),
    }),
    office: Object.freeze({
      target: parsePositiveInteger('DOC_OFFICE_TARGET_BYTES', process.env.DOC_OFFICE_TARGET_BYTES, 5 * 1024 * 1024),
      warn: parsePositiveInteger('DOC_OFFICE_WARN_BYTES', process.env.DOC_OFFICE_WARN_BYTES, 8 * 1024 * 1024),
      max: parsePositiveInteger('DOC_OFFICE_MAX_BYTES', process.env.DOC_OFFICE_MAX_BYTES, 10 * 1024 * 1024),
    }),
  }),
  algoliaApplicationId: process.env.ALGOLIA_APPLICATION_ID?.trim() ?? '',
  algoliaAdminApiKey: process.env.ALGOLIA_ADMIN_API_KEY?.trim() ?? '',
  algoliaSearchOnlyKey: process.env.ALGOLIA_SEARCH_ONLY_KEY?.trim() ?? '',
  algoliaEnabled: parseBoolean(process.env.SEARCH_ENABLED, false),
  algoliaIndexPrefix: process.env.ALGOLIA_INDEX_PREFIX?.trim() || 'paymuster_dev',
  cloudinaryCloudName: process.env.CLOUDINARY_CLOUD_NAME?.trim() ?? '',
  cloudinaryApiKey: process.env.CLOUDINARY_API_KEY?.trim() ?? '',
  cloudinaryApiSecret: process.env.CLOUDINARY_API_SECRET?.trim() ?? '',
  cloudinaryUrl: process.env.CLOUDINARY_URL?.trim() ?? '',
  cloudinaryEnabled: parseBoolean(process.env.CLOUD_STORAGE_ENABLED, false),
  streamAppId: process.env.STREAM_APP_ID?.trim() ?? '',
  streamApiKey: process.env.STREAM_API_KEY?.trim() ?? '',
  streamApiSecret: process.env.STREAM_SECRET_KEY?.trim() ?? '',
  streamEnabled: parseBoolean(process.env.REALTIME_ENABLED, false),
  clerkPublishableKey: process.env.CLERK_PUBLISHABLE_KEY?.trim() ?? '',
  clerkSecretKey: process.env.CLERK_SECRET_KEY?.trim() ?? '',
  clerkEnabled: parseBoolean(process.env.CLERK_ENABLED, false),
  razorpayEnabled: parseBoolean(process.env.RAZORPAY_ENABLED, false),
  razorpayMode,
  razorpayKeyId: process.env.RAZORPAY_KEY_ID?.trim() ?? '',
  razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET?.trim() ?? '',
  razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET?.trim() ?? '',
  razorpayTimeoutMs: parsePositiveInteger('RAZORPAY_TIMEOUT_MS', process.env.RAZORPAY_TIMEOUT_MS, 10_000),
  fcmEnabled: parseBoolean(process.env.FCM_ENABLED, false),
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID?.trim() ?? '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL?.trim() ?? '',
  firebasePrivateKey,
  fcmTimeoutMs: parsePositiveInteger('FCM_TIMEOUT_MS', process.env.FCM_TIMEOUT_MS, 10_000),
  mapsEnabled: parseBoolean(process.env.GOOGLE_MAPS_ENABLED, false),
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY?.trim() ?? '',
  sentryEnabled: parseBoolean(process.env.SENTRY_ENABLED, false),
  sentryDsn: process.env.SENTRY_DSN?.trim() ?? '',
  sentryEnvironment: process.env.SENTRY_ENVIRONMENT?.trim() || nodeEnv,
  sentrySecurityToken: process.env.SENTRY_SECURITY_TOKEN?.trim() ?? '',
  sentryFrontendDsn: process.env.SENTRY_FRONTEND_DSN?.trim() ?? '',
  sentryMobileDsn: process.env.SENTRY_MOBILE_DSN?.trim() ?? '',
  redisEnabled: parseBoolean(process.env.REDIS_ENABLED, false),
  // Multi-company membership mode (blueprint §L): DEFAULT OFF. When off, the
  // tenant middleware's single user.orgId check is authoritative and the
  // memberships table is never consulted.
  multiCompanyEnabled: parseBoolean(process.env.MULTI_COMPANY_ENABLED, false),
  redisUrl: process.env.REDIS_URL?.trim() ?? '',
  upstashRedisRestUrl: process.env.UPSTASH_REDIS_REST_URL?.trim() ?? '',
  upstashRedisRestToken: process.env.UPSTASH_REDIS_REST_TOKEN?.trim() ?? '',
  twilioEnabled: parseBoolean(process.env.TWILIO_ENABLED, false),
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID?.trim() ?? '',
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN?.trim() ?? '',
  awsEnabled: parseBoolean(process.env.AWS_ENABLED, false),
  awsRegion: process.env.AWS_REGION?.trim() ?? '',
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID?.trim() ?? '',
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY?.trim() ?? '',
  brevoEnabled: parseBoolean(process.env.BREVO_ENABLED, false),
  brevoApiKey: process.env.BREVO_API_KEY?.trim() ?? '',
  brevoSmtpKey: process.env.BREVO_SMTP_KEY?.trim() ?? '',
  brevoSmtpHost: process.env.BREVO_SMTP_HOST?.trim() || 'smtp-relay.brevo.com',
  brevoSmtpPort: parsePositiveInteger('BREVO_SMTP_PORT', process.env.BREVO_SMTP_PORT, 587),
  brevoSmtpLogin: process.env.BREVO_SMTP_LOGIN?.trim() ?? '',
  clerkAppId: process.env.CLERK_APP_ID?.trim() ?? '',
  clerkFrontendApiUrl: process.env.CLERK_FRONTEND_API_URL?.trim() ?? '',
  firebaseSenderId: process.env.FIREBASE_SENDER_ID?.trim() ?? '',
  firebaseWebApiKey: process.env.FIREBASE_WEB_API_KEY?.trim() ?? '',
  firebaseAuthDomain: process.env.FIREBASE_AUTH_DOMAIN?.trim() ?? '',
  firebaseStorageBucket: process.env.FIREBASE_STORAGE_BUCKET?.trim() ?? '',
  firebaseAppId: process.env.FIREBASE_APP_ID?.trim() ?? '',
  firebaseMeasurementId: process.env.FIREBASE_MEASUREMENT_ID?.trim() ?? '',
  firebaseVapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY?.trim() ?? '',
  smtpEnabled: parseBoolean(process.env.SMTP_ENABLED, Boolean(emailUser && process.env.EMAIL_APP_PASSWORD)),
  corsOrigins: (process.env.CORS_ORIGINS ?? defaultOrigins.join(','))
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
});

function readiness(enabled: boolean, configured: boolean, supported: boolean): ProviderReadiness {
  if (!enabled) return 'DISABLED';
  if (!supported) return 'ENVIRONMENT_BLOCKED';
  if (!configured) return 'MISSING_CONFIGURATION';
  return 'READY';
}

function providerSummary(
  provider: string,
  kind: ProviderKind,
  enabled: boolean,
  configured: boolean,
  supported: boolean,
  fallback?: string,
  testMode?: boolean,
): ProviderConfigurationSummary {
  return {
    provider,
    kind,
    enabled,
    readiness: readiness(enabled, configured, supported),
    configured,
    testMode,
    fallback,
  };
}

export function providerConfigurationSummary(): ProviderConfigurationSummary[] {
  return [
    providerSummary('gemini', 'AI', config.geminiEnabled, Boolean(config.geminiApiKey), true, 'AI_UNAVAILABLE'),
    providerSummary('algolia', 'SEARCH', config.algoliaEnabled, Boolean(config.algoliaApplicationId && config.algoliaAdminApiKey), true, 'database'),
    providerSummary('cloudinary', 'STORAGE', config.cloudinaryEnabled, Boolean(config.cloudinaryCloudName && config.cloudinaryApiKey && config.cloudinaryApiSecret), true, 'local-private-storage'),
    providerSummary('stream', 'REALTIME', config.streamEnabled, Boolean(config.streamAppId && config.streamApiKey && config.streamApiSecret), true, 'sse-poll-eventbus'),
    providerSummary('clerk', 'AUTH', config.clerkEnabled, Boolean(config.clerkPublishableKey && config.clerkSecretKey), true, 'paymuster-auth'),
    providerSummary('smtp', 'EMAIL', config.smtpEnabled, Boolean(config.emailUser && config.emailAppPassword), true, 'in-app-notification'),
    providerSummary('brevo', 'EMAIL', config.brevoEnabled, Boolean(config.brevoApiKey && config.brevoSmtpKey), true, 'smtp-nodemailer'),
    providerSummary('razorpay', 'PAYMENT', config.razorpayEnabled, Boolean(config.razorpayKeyId && config.razorpayKeySecret), config.razorpayMode === 'test', undefined, config.razorpayMode === 'test'),
    providerSummary('firebase-fcm', 'PUSH', config.fcmEnabled, Boolean(config.firebaseProjectId && config.firebaseClientEmail && config.firebasePrivateKey), true, 'in-app-notification'),
    providerSummary('firebase-web', 'PUSH', true, Boolean(config.firebaseWebApiKey && config.firebaseAppId && config.firebaseProjectId), true, 'in-app-notification'),
    providerSummary('google-maps', 'MAPS', config.mapsEnabled, Boolean(config.googleMapsApiKey), true, 'stored-site-coordinates'),
    providerSummary('sentry', 'OBSERVABILITY', config.sentryEnabled, Boolean(config.sentryDsn), true, 'structured-logger'),
    providerSummary('redis', 'REALTIME', config.redisEnabled, Boolean(config.redisUrl || config.upstashRedisRestUrl), true, 'postgres-event-boundary'),
    providerSummary('twilio', 'EMAIL', config.twilioEnabled, Boolean(config.twilioAccountSid && config.twilioAuthToken), false, 'in-app-and-email'),
    providerSummary('aws', 'STORAGE', config.awsEnabled, Boolean(config.awsRegion && config.awsAccessKeyId && config.awsSecretAccessKey), false, 'existing-storage-boundary'),
  ];
}
