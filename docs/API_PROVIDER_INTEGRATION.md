# PayMuster API Provider Integration

## Scope

This document records the shared provider boundaries currently used by PayMuster. Provider configuration is server-owned. Vendor credentials must never be sent to browser or mobile clients, logged, returned by health endpoints, or persisted in request bodies.

The backend assigns an `X-Request-ID` to every request and includes the same identifier in successful API metadata where the route returns metadata. Unexpected failures are reported through the redacted observability adapter and remain non-transaction-critical.

## Readiness States

- `READY`: enabled, configured, and supported by the current implementation. This is configuration readiness, not proof of live connectivity or delivery.
- `DISABLED`: intentionally off; the documented fallback remains authoritative.
- `MISSING_CONFIGURATION`: enabled but required environment variables are incomplete.
- `ENVIRONMENT_BLOCKED`: intentionally unsupported until the adapter, infrastructure, operational policy, and credentials are approved.
- `INVALID_CONFIGURATION`: malformed or otherwise rejected configuration.

Health is diagnostic only. A provider health response must not expose secrets or claim a vendor operation succeeded when it was not executed. A configured provider remains `UNAVAILABLE` until a supported provider-specific operation supplies real verification evidence.

## Provider Matrix

| Provider | Purpose and boundary | Environment variables | Current state | Fallback or caveat |
| --- | --- | --- | --- | --- |
| PayMuster auth | Authoritative password, Google, JWT, refresh-session, revocation, OTP, and tenant identity flows | `JWT_SECRET`, `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `GOOGLE_WEB_CLIENT_ID` | PASS | Existing PayMuster auth remains authoritative; Clerk is not required. |
| SMTP | Verification, password reset, invitation, and security email templates through the shared `EmailProvider` | `SMTP_ENABLED`, `EMAIL_USER`, `EMAIL_APP_PASSWORD`, `EMAIL_FROM`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SUPPORT_EMAIL`, `EMAIL_LOGO_URL` | PASS when configured; otherwise disabled/skipped | Email delivery is outbox-safe and never transaction-critical. Failed sends retry within the provider boundary and are logged with redacted recipient/event data. |
| Gemini | Server-side AI analysis, summary, insights, and query proposals | `AI_ENABLED`, `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_TIMEOUT_MS` | Configuration-ready locally; live connectivity not asserted by health | Database-backed application behavior remains authoritative. Timeout, provider failure, invalid output, and unsafe proposals fail closed. |
| Algolia | Optional search acceleration through the search adapter | `SEARCH_ENABLED`, `ALGOLIA_APPLICATION_ID`, `ALGOLIA_ADMIN_API_KEY`, `ALGOLIA_SEARCH_ONLY_KEY`, `ALGOLIA_INDEX_PREFIX` | Disabled locally; environment-blocked if enabled | Database search remains authoritative. The current adapter has no network implementation and cannot be activated by credentials alone. |
| Local private storage | Existing authoritative private document/avatar storage boundary | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `DOCUMENT_STORAGE_BUCKET`, `DOCUMENT_UPLOAD_MAX_BYTES`, `DOCUMENT_SIGNED_URL_TTL_SECONDS`, `AVATAR_UPLOAD_MAX_BYTES` | PASS when storage is configured | Uploads validate content signatures and ownership before storage access. Database failure compensates private objects. Signed URLs are short-lived. |
| Cloudinary | Optional media provider | `CLOUD_STORAGE_ENABLED`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CLOUDINARY_URL` | Disabled locally; environment-blocked if enabled | Local/private storage remains authoritative. Upload, removal, and signed URL operations are not network-implemented. |
| Razorpay | Test-mode orders, webhook verification, refunds, reconciliation, idempotency, and subscription billing events | `RAZORPAY_ENABLED`, `RAZORPAY_MODE`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAY_TIMEOUT_MS` | PASS in test mode when keyed; live mode blocked | Live mode is blocked by policy. Webhook signatures, provider event IDs, tenant ownership, and duplicate-event handling are verified before mutation. Billing state is not treated as payment success until a verified event is processed. |
| Firebase FCM | Server-side push fan-out and device-token lifecycle | `FCM_ENABLED`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `FCM_TIMEOUT_MS` | Disabled unless explicitly enabled and keyed | In-app notification records remain durable. Invalid tokens are cleaned up. Notification fan-out is idempotent and not required for the primary transaction. |
| Firebase Crashlytics | Mobile fatal and platform error capture | Firebase mobile configuration and the existing `firebase_crashlytics` dependency | PASS for the configured mobile build | The mobile reporter adds redacted `requestId`, provider, and operation context. Crash reporting must not receive credentials or request bodies. |
| Sentry-compatible observability | Backend and web error-reporting boundary with redaction and correlation context | Backend: `SENTRY_ENABLED`, `SENTRY_DSN`, `SENTRY_ENVIRONMENT`. Web: `VITE_SENTRY_ENABLED`, `VITE_SENTRY_ENVIRONMENT` | Disabled locally; external transport environment-blocked | Structured logger remains authoritative. The dependency-free adapter accepts an injected sink but does not provide an external SDK transport. |
| Stored-coordinate maps | Server-authoritative site coordinates and geofence distance validation | `GOOGLE_MAPS_ENABLED`, `GOOGLE_MAPS_API_KEY` for optional external maps | PASS for stored-coordinate validation; external maps disabled locally | Client geofence claims are not trusted. Coordinates are read from tenant-scoped site data. External Google Maps is optional and not required for attendance validation. |
| SSE/poll/event bus | Existing realtime notification invalidation boundary | No vendor credentials | PASS | Stream is optional. Durable database notifications and polling/SSE-compatible application behavior remain authoritative. |
| Stream | Optional realtime chat/activity provider | `REALTIME_ENABLED`, `STREAM_APP_ID`, `STREAM_API_KEY`, `STREAM_SECRET_KEY` | Disabled locally; environment-blocked if enabled | Existing SSE/poll/event bus remains authoritative. The current adapter does not authorize vendor channels. |
| Clerk | Optional alternative auth integration | `CLERK_ENABLED`, `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY` | Disabled locally; environment-blocked if enabled | PayMuster auth remains authoritative. The current adapter delegates no identity or session operation. |
| Redis | Optional infrastructure cache/rate/realtime provider | `REDIS_ENABLED`, `REDIS_URL` | Environment-blocked | PostgreSQL/application event boundaries remain authoritative until Redis deployment and operations are approved. |
| Twilio | Optional SMS provider | `TWILIO_ENABLED`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | Environment-blocked | In-app notifications and email remain the supported communication paths. |
| AWS | Optional storage/infrastructure provider | `AWS_ENABLED`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Environment-blocked | Existing private storage boundary remains authoritative. |

## Local Phase 2 Checkpoint

The secret-free local registry inspection on 2026-08-23 reported:

| Provider | Enabled | Configured | Readiness | Runtime health | Authoritative fallback |
| --- | --- | --- | --- | --- | --- |
| Gemini | Yes | Yes | `READY` | `UNAVAILABLE` pending a real provider operation | Database-backed application behavior / `AI_UNAVAILABLE` |
| SMTP | Yes | Yes | `READY` | `UNAVAILABLE`; delivery is verified per send attempt | In-app notification |
| Algolia | No | No | `DISABLED` | `DISABLED` | Database search |
| Cloudinary | No | No | `DISABLED` | `DISABLED` | Local private storage |
| Stream | No | No | `DISABLED` | `DISABLED` | SSE, polling, and application event bus |
| Clerk | No | No | `DISABLED` | `DISABLED` | PayMuster auth |
| Razorpay | No | No | `DISABLED` | `DISABLED` | No payment success is fabricated |
| Firebase FCM | No | No | `DISABLED` | `DISABLED` | Durable in-app notification |
| External Google Maps | No | No | `DISABLED` | `DISABLED` | Stored site coordinates and server geofence validation |
| Sentry external transport | No | No | `DISABLED` | `DISABLED` | Redacted structured logger |
| Redis | No | No | `DISABLED` | `DISABLED` | PostgreSQL/application event boundary |
| Twilio | No | No | `DISABLED` | `DISABLED` | In-app notification and email |
| AWS | No | No | `DISABLED` | `DISABLED` | Existing private storage boundary |

`READY` in this checkpoint means the server-side configuration contract is complete. It does not mean that a network request was made or that delivery, quota, webhook, billing, or production policy was verified.

## Activation Gates

- Keep Algolia, Cloudinary, Stream, Clerk, Sentry external transport, Redis, Twilio, and AWS disabled until their real adapter implementation, free-tier or billing ownership, timeout/retry behavior, fallback behavior, and provider-specific tests are approved.
- Keep Razorpay disabled unless an operator deliberately enables test mode. Live mode remains blocked until webhook delivery, refunds, reconciliation, subscription lifecycle, invoice/tax/settlement policy, and operational ownership have staging evidence.
- Keep Firebase FCM disabled until a server-only service account is provisioned and authenticated send, invalid-token cleanup, retry, and durable in-app fallback are verified in a non-production Firebase project.
- Keep external Google Maps disabled unless server-side API restrictions, quota ownership, and fallback behavior are verified. Stored coordinates remain authoritative for attendance.
- Treat Gemini and SMTP as pending live verification despite configuration readiness. Record a correlation ID and redacted provider outcome from a safe operator-owned operation before declaring connectivity.
- Store all secrets only in the deployment platform's server-side secret manager. Never place admin, secret, private-key, webhook-secret, or service-role values in web/mobile environment files.

## Routes and Permissions

All protected routes require the existing PayMuster auth middleware and tenant context. Controllers return `requestId` metadata where applicable. The following provider-facing or provider-dependent routes are currently implemented:

| Route | Provider/domain boundary | Permission or scope |
| --- | --- | --- |
| `GET /health` | Backend liveness | Public; reports only service liveness. |
| `GET /auth/*` | PayMuster auth, OTP, SMTP delivery | Public auth actions; maintenance and identity checks are enforced server-side. |
| `GET /api/v1/admin/providers/health` | Provider readiness and safe diagnostics | Super Admin/provider-health rate limit. Secrets are redacted. |
| `POST /api/v1/ai/analyze` | Gemini adapter with database fallback | `view_reports`; tenant-scoped context. |
| `POST /api/v1/ai/summary` | Gemini adapter with database fallback | `view_reports`; tenant-scoped context. |
| `POST /api/v1/ai/insights` | Gemini adapter with database fallback | `view_reports`; tenant-scoped context. |
| `POST /api/v1/ai/query` | Gemini adapter with fail-closed query proposals | `view_reports`; tenant-scoped context. |
| `POST /api/v1/push/devices` | FCM device registration | Authenticated user; token belongs to the authenticated user and organization. |
| `DELETE /api/v1/push/devices` | FCM token unregister/revocation | Authenticated user; tenant and user scoped. |
| `GET /api/v1/documents` | Private storage listing | Authenticated owner/staff scope. |
| `POST /api/v1/documents` | Private storage upload and database/audit transaction | Active authorized staff; MIME signature, size, tenant, and ownership validation. |
| `POST /api/v1/documents/:id/view` | Short-lived private signed URL | Authenticated document owner or authorized admin scope. |
| `GET /api/v1/announcements` | Durable in-app notification store | Authenticated recipient scope. |
| `GET /api/v1/announcements/stream` | Notification invalidation stream | Authenticated recipient scope. |
| `POST /api/v1/announcements/:id/acknowledge` | Durable notification acknowledgement | Authenticated recipient; append-only audit behavior. |
| `GET /api/v1/company`, `PATCH /api/v1/company/settings` | Tenant company data | Company tenant scope and role permissions. |
| `GET/POST /api/v1/attendance` | Attendance and server-side location validation | Company tenant scope; site coordinates are authoritative. |
| `GET/POST /api/v1/payroll` | Workforce payroll and financial integrity | Company tenant scope and payroll permissions. |

Razorpay webhook, refund, reconciliation, and subscription operations are backend service boundaries. They are intentionally not exposed as unrestricted client provider endpoints. Administrative operations require the existing Super Admin or tenant role checks defined by their controllers and services.

## Failure, Timeout, and Retry Rules

- Provider calls use bounded timeouts where the provider supports network calls, including `GEMINI_TIMEOUT_MS`, `RAZORPAY_TIMEOUT_MS`, `FCM_TIMEOUT_MS`, and SMTP transport timeouts.
- Retries are limited to transient provider delivery failures and use bounded attempts. Non-retryable validation, signature, authorization, tenant-isolation, and malformed-response failures fail closed.
- Email, push, search acceleration, AI, realtime acceleration, and observability are not transaction-critical. Primary database mutations do not roll back because an optional notification or telemetry sink is unavailable.
- Razorpay webhook processing is idempotent by provider event ID and verifies the signature before applying billing mutations.
- FCM invalid-token responses remove the invalid registration. A durable in-app notification is retained when push delivery is unavailable.
- Provider errors are logged with event IDs, operation names, status, and correlation IDs. Secrets, bearer tokens, OTPs, request bodies, and private keys are excluded.
- Health endpoints describe configuration/readiness and fallback behavior. They do not perform fabricated payment, email, push, or AI success operations.

## Billing and Test Mode

Razorpay must remain `RAZORPAY_MODE=test` until live credentials, webhook delivery, refund behavior, reconciliation, subscription lifecycle, invoice behavior, tax/settlement policy, and operational ownership are verified. Test-mode provider events must not be mistaken for production revenue.

Subscription services enforce plan, trial, entitlement, usage, invoice, and payment-event invariants server-side. Super Admin access is unlimited and does not depend on tenant billing state. Owner Dashboard UI is outside this foundation scope.

## Security Notes

- Keep `.env` files and service-account credentials out of source control.
- Use server-only credentials for SMTP, Supabase service role, Cloudinary secret, Stream secret, Razorpay secret/webhook secret, FCM private key, Sentry DSN, Twilio auth token, and AWS secret.
- Never trust client-provided organization IDs, site ownership, geofence results, payment status, webhook event type, or notification delivery claims without server-side verification.
- Normalize emails before identity lookup and fail closed on ambiguous identity matches.
- Redact fields matching password, OTP, token, secret, authorization, cookie, credential, private key, API key, or DSN patterns before logging or telemetry.
- Signed document URLs are short-lived and generated only after tenant and ownership checks.
- API responses expose stable error codes and safe messages, with `X-Request-ID` available for support correlation.

## Verification Evidence

- Backend: TypeScript build passes; the full suite passes all 170 tests. Focused provider tests cover retries, signatures, fallbacks, tenant authorization, live-payment blocking, health redaction, and configuration summaries.
- Frontend: `npm run build` passes with the TypeScript project build and Vite production bundle.
- Mobile: `flutter analyze` reports no issues and `flutter test` passes all 84 tests. Dependency resolution reports advisory updates and one discontinued package, but no analysis or test failure.
- Runtime: an isolated local backend process returned HTTP 200 from `GET /health` and returned a generated `X-Request-ID` without exposing credentials in the response.
- Prisma: client generation passed and the five additive migration SQL files executed successfully against local `paymuster_dev`. `prisma migrate status` still reports history drift: those five migration names are absent from the database ledger, while older database migration names are absent from this checkout. No reset, drop, or forced migration resolution was performed.
- External vendor delivery was not fabricated. SMTP connectivity was verified without sending a message; FCM, Razorpay, Gemini, Algolia, Cloudinary, Stream, Clerk, Sentry, Google Maps, Redis, Twilio, and AWS remain subject to the documented activation gate before live verification.
