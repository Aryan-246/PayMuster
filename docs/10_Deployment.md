# Deployment & Infrastructure

## Overview

PayMuster is deployed for SMB-scale operations — not hyperscale enterprise infrastructure. We prioritize **developer velocity, operational simplicity, and cost efficiency** over multi-region Kubernetes clusters. The architecture uses managed services wherever possible to minimize DevOps overhead.

---

## 1. Infrastructure Stack

| Layer | Service | Purpose |
|---|---|---|
| **Database** | Supabase (PostgreSQL) | Primary cloud database, RLS, real-time subscriptions, auth, storage |
| **Backend API** | Railway or Render | Node.js API hosting with auto-deploy from Git |
| **Web Dashboard** | Vercel | React app hosting with CDN, preview deployments per PR |
| **Mobile App** | Google Play Store + Apple App Store | Flutter app distribution |
| **Mobile Beta** | Firebase App Distribution | Internal testing builds before store submission |
| **File Storage** | Supabase Storage | Photos (attendance, receipts, assets), documents (Aadhaar, PAN) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Push notifications to mobile devices |
| **Email (Transactional)** | Resend or Postmark | Password reset, payment receipts, invitation emails |
| **DNS & CDN** | Cloudflare | DNS management, DDoS protection, edge caching for static assets |
| **Payment Gateway** | Razorpay / Cashfree | Payment processing, webhook callbacks for Failed/Paid statuses |

---

## 2. Environments

| Environment | Purpose | Deploy Trigger |
|---|---|---|
| **Development** | Local development with Supabase local (Docker) | Manual |
| **Staging** | Pre-production testing with a separate Supabase project | Auto-deploy on merge to `develop` branch |
| **Production** | Live user-facing environment | Manual promotion from staging after QA sign-off |

### Environment Variables
- All secrets (Supabase keys, JWT secret, FCM keys) are stored in the hosting provider's environment variable management (Railway/Vercel/Render).
- **No secrets are committed to Git.** Ever. The `.gitignore` includes `.env*` patterns.
- A `.env.example` file in the repo documents all required variables with placeholder values.

---

## 3. CI/CD Pipeline (GitHub Actions)

### Trigger: Pull Request Opened

```yaml
# Simplified pipeline representation
lint → unit-tests → integration-tests → build → deploy-preview
```

| Step | Action | Blocking? |
|---|---|---|
| **Lint** | ESLint (backend + web), Dart Analyzer (Flutter) | ✅ Yes |
| **Unit Tests** | Jest/Vitest (backend + web), flutter_test (mobile) | ✅ Yes |
| **Integration Tests** | Supertest against Testcontainers Postgres | ✅ Yes |
| **Build** | Compile backend, build React app, build Flutter APK | ✅ Yes |
| **Preview Deploy** | Vercel preview URL for web dashboard | Informational |

### Trigger: Merge to `develop`

```yaml
deploy-staging → e2e-tests → notify
```

| Step | Action |
|---|---|
| **Deploy Staging** | Backend deployed to Railway staging. Web deployed to Vercel staging. |
| **E2E Tests** | Playwright runs against staging web. Flutter integration_test runs against staging API. |
| **Notify** | Slack notification with staging URL and test results. |

### Trigger: Release Tag (`v1.x.x`)

```yaml
deploy-production → smoke-test → notify
```

| Step | Action |
|---|---|
| **Deploy Production** | Backend deployed to Railway production. Web deployed to Vercel production. |
| **Smoke Test** | Hit critical health check endpoints. Verify auth flow. Verify database connectivity. |
| **Notify** | Slack notification confirming production deployment. |

### Flutter Release Pipeline

| Step | Action |
|---|---|
| **Build APK / AAB** | `flutter build appbundle --release` |
| **Build IPA** | `flutter build ipa --release` (macOS runner) |
| **Beta Distribution** | Upload to Firebase App Distribution for internal testing |
| **Store Submission** | Manual submission to Google Play Console and App Store Connect after QA |

---

## 4. Database Migrations

- Migrations are managed via a migration tool (e.g., Prisma Migrate or `dbmate`).
- Every migration has an **up** and **down** script.
- Migrations run automatically during the deploy step for staging and production.
- **Zero-downtime migrations only**: No locking operations on production tables.
- Migration files are version-controlled in the `/database/migrations/` directory.

---

## 5. Monitoring & Alerting

| Concern | Tool | What We Monitor |
|---|---|---|
| **API Health** | UptimeRobot or BetterStack | Ping `/health` endpoint every 60 seconds. Alert if down for > 2 minutes. |
| **Error Tracking** | Sentry | Unhandled exceptions in backend, web, and Flutter. Grouped by issue. Alert on new error spikes. |
| **Logging** | Pino (structured JSON) → Railway/Render built-in log viewer | Request logs, error logs, audit events. Retained for 30 days. |
| **Database** | Supabase Dashboard | Connection pool usage, slow queries (> 500ms), storage utilization. |
| **Performance** | Sentry Performance Monitoring | API endpoint latency (p50, p95, p99). Alert if p95 > 1 second. |

### Alerting Rules
| Condition | Severity | Action |
|---|---|---|
| API returns 5xx for > 1 minute | 🔴 Critical | Immediate Slack + SMS alert |
| Error rate > 5% of requests | 🟠 High | Slack alert |
| Database CPU > 80% sustained | 🟠 High | Slack alert |
| Deployment fails | 🔴 Critical | Slack alert, auto-rollback if supported |
| SSL certificate expiring in < 14 days | 🟡 Warning | Slack alert |

---

## 6. Backup & Recovery

| Data | Strategy | Retention |
|---|---|---|
| **PostgreSQL** | Supabase automated daily backups + Point-in-Time Recovery (PITR) | 30 days |
| **File Storage** | Supabase Storage with redundancy | As long as the org exists |
| **Configuration** | All infra config in Git (IaC) | Permanent (Git history) |

### Recovery Plan
- **Database corruption**: Restore from Supabase PITR to the last known good timestamp. Estimated RTO: < 30 minutes.
- **Backend failure**: Railway auto-restarts crashed instances. If persistent, rollback to previous deployment.
- **DNS failure**: Cloudflare provides automatic failover and DDoS mitigation.

---

## 7. Security Hardening

| Measure | Implementation |
|---|---|
| **HTTPS Everywhere** | Enforced via Cloudflare and hosting providers. No HTTP traffic allowed. |
| **CORS** | Restricted to `app.paymuster.com` (web) and the mobile app's user-agent. |
| **Rate Limiting** | Redis-backed (or in-memory) sliding window. 100 req/min public, 300 req/min authenticated. |
| **Helmet** | Express `helmet` middleware for security headers (CSP, HSTS, X-Frame-Options). |
| **Dependency Audit** | `npm audit` and `flutter pub outdated` run in CI. Critical CVEs block deployment. |
| **Secret Rotation** | JWT signing key rotated quarterly. Supabase service keys rotated on security incidents. |

---

## 8. Scaling Path (Future)

PayMuster is architected for SMB scale today but designed to scale when needed:

| Trigger | Action |
|---|---|
| API response times degrade (p95 > 500ms) | Add horizontal replicas on Railway/Render |
| Database connection pool exhaustion | Enable Supabase connection pooler (Supavisor) or migrate to a dedicated Postgres instance |
| File storage exceeds 100GB | Evaluate moving to dedicated S3 bucket with Cloudflare R2 |
| User base exceeds 10,000 orgs | Evaluate migration from managed hosting to containerized deployment (Docker on AWS ECS) |
| Need for real-time collaboration | Evaluate Supabase Realtime channels or dedicated WebSocket service |
