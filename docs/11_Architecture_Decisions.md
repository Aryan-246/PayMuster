# Architecture Decisions & Phase Gates

**Status:** Approved documentation baseline — no implementation implied  
**Version:** 1.0.0  
**Last Updated:** 2026-07-30

---

## Purpose

This document resolves architectural conflicts discovered during the Phase 1 audit and defines the gates that must be satisfied before implementation continues. It is intentionally specific: PayMuster is a production Workforce Operating System, and its interfaces, routes, permissions, data boundaries, and offline behavior must be designed as one system.

This document records decisions. It does not authorize application-code changes.

## Source of Truth Order

When specifications disagree, use this order:

1. Explicit user decisions for the current project
2. `design/DesignSystem.md` for product design, UX, navigation, accessibility, localization, and visual tokens
3. This document for resolved architecture decisions and implementation gates
4. `docs/01_Project_Vision.md` through `docs/10_Deployment.md` for product and technical requirements
5. `prompts/` for role-specific delivery guidance
6. `README.md` for project orientation
7. Existing code and generated artifacts

Code never establishes product requirements. If a later decision changes an approved specification, update the relevant source-of-truth document before changing code.

---

## Audit Snapshot

The current repository is a foundation/prototype, not a partially complete production application.

| Area | Current state | Architecture implication |
|---|---|---|
| Web | One rendered dashboard shell, no client route map, hard-coded sample data, duplicate layout families | Do not extend dashboard components into modules before navigation, tokens, and shared primitives exist |
| Mobile | One GoRouter route, one dark theme, static shell, no localization, device service, offline database, or sync implementation | Mobile must first receive app bootstrap, token, navigation, localization, and offline contracts |
| Backend | Express server exposes only `/health`; documented API, auth, RBAC, upload, audit, and sync contracts are unimplemented | Feature UI cannot be treated as production-integrated until API contracts are delivered per module |
| Database | Broad Prisma schema exists, but policy/migration evidence is incomplete and some required roles/contracts differ from product docs | Data/RBAC and money/time precision decisions must be resolved before feature migrations |
| Documentation | Product and design intent are strong; legacy UI prompts and README values conflict with the Design System | This document and the Design System prevent old palette/role guidance from being copied into new work |

The audit also found existing uncommitted UI, asset, and generated-output changes. Those files are preserved and must not be deleted, renamed, or treated as approved architecture without a separate review.

---

## Resolved Decisions

### AD-001 — PayMuster is a Workforce Operating System

**Decision:** Product language, navigation, permissions, and dashboard behavior use **Workforce Operating System** as the primary identity. Payroll, HR, ERP, CRM, and accounting are supporting domains, not the product definition.

**Implication:** The default experience is an operational control layer that connects workforces, sites, proof, attendance, payroll, approvals, and inventory. A generic KPI-card dashboard is not a sufficient information architecture.

### AD-002 — Canonical design tokens use the Design System teal palette

**Decision:** `design/DesignSystem.md` version 1.1 is the canonical visual token source. Its teal primary (`#15D1C2`), deep teal secondary (`#0E7C86`), dark surfaces, typography, spacing, radii, elevation, motion, and component behavior supersede the legacy yellow-primary values in `README.md`, `docs/08_UI.md`, and selected files in `prompts/`.

**Implication:** Yellow/amber remains a semantic warning and pending-state color, never the global primary action color. New work uses semantic tokens rather than raw hex values, arbitrary Tailwind values, or visual effects such as glassmorphism and decorative gradients.

### AD-003 — Canonical roles and transitional labels

**Decision:** The planned role model is `Owner`, `Admin`, `Manager`, `Supervisor`, `Accountant`, `Worker`, and `Guest`.

`Staff` is the legacy data/domain term for a worker. `Viewer` is the legacy user-facing term for a guest. Until an approved data migration is implemented, interfaces may map `Worker → STAFF` and `Guest → VIEWER`; they must not expose conflicting labels in the same user journey. `Manager` is not yet present in the database enum and must not appear in assignable role controls until RBAC schema, policy, and tests support it.

**Implication:** Permissions are policy-driven, deny-by-default, scope-aware, and applied equally to routes, API responses, search, exports, notifications, AI context, and cached/offline data.

### AD-004 — Navigation and route contract precede feature implementation

**Decision:** Both clients use the same canonical route IDs and deep-link semantics. The web client will use a route library during the Navigation phase; Flutter continues with GoRouter. A route is complete only when it resolves an accessible screen or a defined state (`loading`, `empty`, `error`, `offline`, `permission denied`, or `not found`).

**Canonical route map:**

| Workspace | Route IDs |
|---|---|
| Public | `/splash`, `/onboarding`, `/language`, `/appearance`, `/login`, `/otp`, `/forgot-password`, `/reset-password`, `/invite/:token` |
| Setup | `/setup/organization`, `/setup/site`, `/setup/worker`, `/setup/complete` |
| Home | `/app/dashboard`, `/app/search`, `/app/command`, `/app/notifications`, `/app/activity`, `/app/approvals`, `/app/offline-queue`, `/app/conflicts` |
| Workers | `/app/workers`, `/app/workers/new`, `/app/workers/:workerId`, `/app/workers/:workerId/edit`, `/app/workers/:workerId/documents`, `/app/workers/:workerId/attendance`, `/app/workers/:workerId/payments`, `/app/workers/:workerId/sites`, `/app/workers/:workerId/assets`, `/app/workers/:workerId/advances`, `/app/workers/:workerId/ledger`, `/app/workers/:workerId/final-settlement` |
| Attendance | `/app/attendance`, `/app/attendance/mark`, `/app/attendance/:attendanceId`, `/app/attendance/corrections/:requestId`, `/app/attendance/conflicts/:conflictId` |
| Sites | `/app/sites`, `/app/sites/new`, `/app/sites/:siteId`, `/app/sites/:siteId/edit`, `/app/sites/:siteId/assignments`, `/app/sites/:siteId/attendance`, `/app/sites/:siteId/proofs`, `/app/sites/:siteId/assets`, `/app/sites/:siteId/materials`, `/app/sites/:siteId/expenses`, `/app/sites/:siteId/costs` |
| Payroll | `/app/payroll`, `/app/payroll/cycles/new`, `/app/payroll/cycles/:cycleId`, `/app/payroll/cycles/:cycleId/workers/:workerId`, `/app/payroll/cycles/:cycleId/calculate`, `/app/payroll/cycles/:cycleId/slips/:workerId`, `/app/payroll/rules` |
| Payments & Expenses | `/app/payments`, `/app/payments/new`, `/app/payments/batch`, `/app/payments/:paymentId`, `/app/payments/:paymentId/confirm`, `/app/payments/:paymentId/retry`, `/app/payments/:paymentId/audit`, `/app/advances`, `/app/advances/:advanceId`, `/app/expenses`, `/app/expenses/new`, `/app/expenses/:expenseId`, `/app/expenses/:expenseId/approve`, `/app/expenses/:expenseId/reimburse`, `/app/expenses/:expenseId/receipt` |
| Operations | `/app/assets`, `/app/assets/new`, `/app/assets/:assetId`, `/app/assets/:assetId/edit`, `/app/assets/:assetId/issue`, `/app/assets/:assetId/return`, `/app/assets/:assetId/transfer`, `/app/assets/:assetId/damage`, `/app/assets/:assetId/review`, `/app/materials`, `/app/materials/new`, `/app/materials/:materialId/edit`, `/app/materials/stock`, `/app/materials/transactions/new`, `/app/materials/deliveries/:deliveryId`, `/app/materials/alerts` |
| Relationships | `/app/clients`, `/app/clients/new`, `/app/clients/:clientId`, `/app/clients/:clientId/edit`, `/app/vendors`, `/app/vendors/new`, `/app/vendors/:vendorId`, `/app/vendors/:vendorId/edit`, `/app/vendors/:vendorId/payments` |
| Intelligence | `/app/reports`, `/app/reports/:reportId`, `/app/reports/:reportId/export`, `/app/ai`, `/app/ai/settings` |
| Organization | `/app/profile`, `/app/settings`, `/app/settings/organization`, `/app/settings/users`, `/app/settings/attendance-payroll`, `/app/settings/payments-expenses`, `/app/settings/notifications`, `/app/settings/appearance`, `/app/settings/integrations`, `/app/settings/billing`, `/app/audit-log`, `/app/help`, `/app/about`, `/app/privacy`, `/app/terms` |

Record details may render as a full page on mobile and a page, panel, or modal entry point on desktop, but the same route must remain shareable, accessible, permission-checked, and deep-linkable on both platforms.

### AD-005 — Shared feature boundaries without premature reorganization

**Decision:** No existing folder is moved during Phase 1. New implementation follows feature ownership rather than expanding a single `components/layout` directory.

| Platform | Approved target ownership |
|---|---|
| Web | `src/app` for providers/bootstrap; `src/routes` for route composition; `src/features/<domain>` for domain screens, hooks, and types; `src/components/ui` for token-driven reusable primitives; `src/components/layout` for shell-only composition; `src/lib` for API, formatting, and shared utilities |
| Mobile | `lib/app` for bootstrap/router; `lib/core` for theme, localization, network, storage, and permissions; `lib/features/<domain>` for presentation, application, and data layers; `lib/shared` for reusable UI primitives |
| Backend | `src/modules/<domain>` for route, validation, service, repository, and policy layers; `src/shared` for auth, audit, error, and infrastructure concerns; Prisma remains the schema/migration boundary |

**Implication:** Existing duplicate `Sidebar`, `Topbar`, and dashboard component families are audit evidence, not components to extend. Consolidation requires an approved navigation/component implementation phase and must preserve any intentional user work.

### AD-006 — Theme and localization are global capabilities

**Decision:** Dark, Light, AMOLED, and System theme modes plus English (`en-IN`), Hindi (`hi-IN`), and Punjabi (`pa-IN`) are application-level preferences, not per-page settings. UI strings use message keys. User-entered company, worker, site, material, asset, and legal names remain untouched.

**Implication:** A feature cannot introduce raw display strings, a private color palette, or a separate preference store. Theme and locale must be restored before the authenticated shell renders and must be available to error/loading screens.

### AD-007 — Offline state is a first-class domain contract

**Decision:** Offline workflows use explicit record states: `saved_offline`, `syncing`, `synced`, `upload_pending`, `needs_review`, and `sync_failed`. Attendance and proof capture are supported offline; server-authoritative financial approvals, payment submission, role changes, and billing require a connection.

**Implication:** The mobile client requires a local data schema, durable mutation queue, media-first upload strategy, retry/backoff policy, conflict presentation, and permission-safe cache eviction before field workflows are implemented. Financial records are server-authoritative; attendance conflicts require an authorized human resolution with an audit reason.

### AD-008 — Security and data integrity are delivery gates

**Decision:** The documented API is the only client data boundary. Every mutation needs validation, authorization, audit logging, transaction boundaries where needed, and idempotency for retryable requests. Currency and financial multipliers use exact decimal representations; floating-point values must not determine money.

**Implication:** Before API feature work begins, the project needs documented/implemented JWT session strategy, RBAC policy enforcement, multi-tenant row-level security, secure file upload policy, idempotency-key behavior, and an error contract. The current health-only server is not an integration substitute.

---

## Required Documentation Gates

The following documents must be approved before their corresponding implementation phase begins:

| Before phase | Documentation gate |
|---|---|
| Design tokens | Cross-platform token mapping: CSS/Tailwind semantic tokens and Flutter theme extensions |
| Theme | Preference persistence, theme-token mapping, contrast validation, AMOLED surface rules |
| Localization | Message-key ownership, translation catalog structure, locale persistence, date/number/currency policy |
| Navigation | Role-to-navigation manifest, route guards, deep-link/error behavior, Command Center command registry |
| Authentication | Session model, invitation/reset flows, protected-route states, device/session revocation UX |
| Any domain module | Domain workflow, schema/migration, API contract, permission map, offline behavior, audit events, test matrix |
| AI capability | Data masking, confidence policy, confirmation UX, read-only query boundary, fallback/error behavior |

Every gate is additive to the Design System’s existing requirements for accessibility, motion, responsive behavior, loading/empty/error states, and future extensibility.

---

## Known Inconsistencies Recorded for Resolution

| ID | Finding | Resolution path |
|---|---|---|
| ARC-01 | Legacy documentation describes yellow as the primary action color; the Design System specifies teal | AD-002 makes the Design System canonical; legacy documents are updated only in a documentation maintenance phase |
| ARC-02 | Product docs use `Staff`/`Viewer`; requested product roles use `Worker`/`Guest` and add `Manager` | AD-003 defines labels and blocks Manager assignment until a schema/RBAC migration is designed |
| ARC-03 | Current web/mobile shells contain hard-coded strings, raw colors, arbitrary radii, sample dollar values, and non-functional controls | Treat as prototype-only; token, localization, navigation, and real data contracts must precede extension |
| ARC-04 | Current web has no router and mobile has only `/`, while the screen inventory requires a full deep-linkable product | AD-004 is the canonical route contract and Navigation-phase prerequisite |
| ARC-05 | Offline-first is documented, but the mobile code contains no local database schema, queue, media upload, permission, GPS, camera, or conflict UI | AD-007 blocks field workflow implementation until these contracts are designed |
| ARC-06 | Documents require RLS, RBAC, audit, idempotency, and API contracts; current backend provides only health check | AD-008 blocks feature integration until the backend foundation is designed and tested |
| ARC-07 | `mobile/README.md` remains the default Flutter template and does not describe the product | Update in a documentation maintenance phase once mobile architecture and local development workflow are approved |

---

## Phase Status

**Phase 1 — Documentation:** Active. The Design System and this decision record define product foundations and implementation gates.

**Next authorized work:** review and approve this document. After approval, the next phase is Design Tokens, beginning with the required cross-platform token-mapping document. No application code is authorized by this record.
