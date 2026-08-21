# Production Readiness Report

**Assessment date:** 2026-08-18  
**Decision:** **NOT READY FOR PRODUCTION PROMOTION**  
**Scope:** Current PayMuster backend, Flutter application, React frontend, persistent announcements, Admin workflows, identity hardening, tenant isolation, and protected operational/financial data.

## Executive Summary

The current codebase passes the available local compilation, static-analysis, unit/widget, schema-validation, release-build, and synthetic browser visual gates. Persistent announcements and the Admin dispatch experience are implemented and have focused backend, transport, widget, permission-route, and durable-refetch coverage.

Production promotion remains blocked. Read-only evidence identifies unresolved normalized-email collisions and tenant-affiliation mismatches that require authorized operator review. Multi-instance announcement invalidation also requires shared event transport, and authenticated staging browser/security verification has not been completed against an explicitly approved non-production environment.

No production endpoint was contacted during this assessment. No migration, seed, reset, repair, update, deletion, or schema mutation was executed. The database integrity query ran only after its local/non-production guard passed and used a read-only transaction.

## Verified Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| Flutter formatting | Pass | Admin API transport test formatted with no changes required |
| Flutter static analysis | Pass | `flutter analyze`: no issues found |
| Focused Admin transport tests | Pass | 5 tests |
| Focused announcement/Admin/route tests | Pass | 31 tests |
| Complete Flutter test suite | Pass | 75 tests |
| Flutter web release build | Pass | JavaScript release build completed; Wasm compatibility dry run succeeded |
| Backend TypeScript build | Pass | `npm run build` completed |
| Complete backend test suite | Pass | 70 tests, 0 failures |
| Prisma schema validation | Pass | `prisma validate`: schema valid |
| React frontend production build | Pass | TypeScript project build and Vite production build completed |
| Local browser visual gate | Pass, limited scope | Synthetic token-free Admin settings route at 1440×900; no runtime failures; screenshot evidence generated |
| Guarded database integrity check | Executed, blockers found | Local explicitly non-production target; transaction set to read-only; no orphan counts; non-zero tenant mismatch counts |

## Persistent Announcement Evidence

The implemented announcement contract is documented in [API Documentation](05_APIs.md#persistent-announcements-implemented).

Verified behavior includes:

- Super Admin dispatch is gated by authentication and `manage_system`.
- System-wide dispatch can include eligible authenticated users without organization affiliation.
- Organization dispatch validates and scopes organization context.
- One recipient-scoped `ANNOUNCEMENT` notification is created per eligible user.
- Campaign and acknowledgement evidence is written transactionally.
- Dispatch responses and campaign audit payloads expose campaign metadata and recipient counts, not recipient identities.
- Recipient listing and acknowledgement are scoped to the authenticated user.
- First acknowledgement conditionally records `readAt`; repeated acknowledgement is side-effect free.
- The Flutter client treats the persistent list/refetch path as authoritative after initial load, pull-to-refresh, app resume, polling, acknowledgement, reconnect, and stream invalidation.
- Server-sent events carry invalidation metadata only and are not treated as a durable queue.
- Admin dispatch validation, duplicate-submit prevention, success/error feedback, and durable notification-log refresh have widget coverage.

## Read-Only Integrity Evidence

The guarded integrity harness requires a local database host and a database name explicitly marked as development, test, staging, or local. It then executes `SET TRANSACTION READ ONLY` before aggregate queries.

Observed row counts:

| Relation | Count |
| --- | ---: |
| Sites | 1 |
| Site members | 2 |
| Site assignments | 0 |
| Attendance records | 2 |
| Pay cycles | 1 |
| Pay runs | 2 |
| Pay-run items | 2 |
| Expenses | 0 |
| Payments | 0 |

All measured orphan-parent counts were zero.

The following tenant-consistency aggregates were non-zero:

| Check | Count |
| --- | ---: |
| Site member organization differs from user organization | 2 |
| Attendance organization differs from site organization | 1 |
| Attendance organization differs from staff organization | 1 |
| Attendance organization differs from marker organization | 2 |
| Pay-run organization differs from pay-cycle organization | 1 |
| Pay-run organization differs from approver organization | 2 |
| Pay-run-item organization differs from staff organization | 1 |

These rows were not changed. The counts are blockers requiring restricted operator review of current affiliations and historical evidence. They must not be repaired by inventing tenant context, reassigning records from inferred names, nulling relationships, deleting history, or deriving payroll Site attribution that the schema does not represent.

## Production Blockers

### 1. Global Email Identity Collisions

The [Global Email Identity Migration Plan](12_Global_Email_Identity_Migration.md) records three duplicate normalized-email groups containing eight verified user identities across multiple organizations. Runtime authentication fails closed with `ACCOUNT_IDENTITY_CONFLICT`, but database-level global uniqueness remains blocked.

Required closure evidence:

- An authorized operator resolves every collision using verified identity and organization evidence.
- Sessions for affected identities are revoked during approved remediation.
- Attendance, payroll, organization, staff, and audit history is preserved.
- Read-only preflight reports zero normalized-email collisions and zero non-normalized stored addresses.
- The approved global uniqueness constraint is applied and validated through a separately approved migration process.
- Prisma schema and database constraint agree.

### 2. Tenant-Affiliation Mismatches

The non-zero guarded integrity aggregates listed above prevent tenant data sign-off. Their causes cannot be inferred safely from row counts alone.

Required closure evidence:

- Restricted row-level investigation on an approved snapshot or read replica.
- Business-owner or security-operator disposition for each mismatch.
- Backed-up, auditable, explicitly approved remediation transactions where required.
- Repeated read-only checks showing zero unexplained mismatches.
- Tenant-isolation regression and authorization tests after remediation.

### 3. Organization Membership and Owner Ambiguity

The [Organization Membership and Owner Evidence Migration Plan](14_Organization_Membership_and_Owner_Evidence_Migration.md) records unresolved Owner/organization findings and states that true multi-company context is not production-ready. Organization membership must be represented explicitly rather than through duplicate identities or inferred current ownership.

No automatic role change, affiliation move, organization deletion, ownership replay, or historical-record reassignment is authorized.

### 4. Multi-Instance Announcement Invalidation

The current announcement event bus is process-local. Durable list/refetch behavior prevents the stream from becoming authoritative, but multi-process or multi-instance deployments require shared event transport before real-time invalidation can be considered a scalability guarantee.

Acceptable closure requires a reviewed shared transport, recipient-scoped delivery authorization, reconnect/backpressure behavior, and failure tests proving durable refetch still recovers missed invalidations.

### 5. Authenticated Staging Browser and Security Gate

The completed browser check used a synthetic Super Admin identity, no access token, a local static server, and a local isolated Chrome profile. It verifies rendering only. It does not replace authenticated staging E2E.

Required closure evidence in an explicitly approved non-production environment:

- Sign-in, refresh, logout, and revocation flows.
- Role and route isolation for ordinary users, organization roles, and Super Admin.
- Tenant-header and authenticated-context isolation.
- Announcement system and organization dispatch, recipient persistence, acknowledgement, missed-event recovery, and audit evidence.
- Admin destructive-action failure handling and reversible-action audit evidence.
- Responsive desktop/mobile navigation and error states.
- Security-header, CORS, rate-limit, upload, signed-document access, and session invalidation checks.

No authenticated browser mutation gate should run until the target, credentials, rollback plan, and permitted test data are explicitly approved.

### 6. Production Verification Intentionally Not Performed

Production was not contacted, queried, migrated, or modified. Therefore, this report cannot certify production database state, deployed infrastructure, secrets, storage policy, shared-event topology, restore capability, or runtime observability.

## Data Protection Constraints

The following constraints remain mandatory through remediation and deployment:

- Never reset, truncate, destructively reseed, or automatically repair production data.
- Never automatically create or apply production migrations.
- Preserve users, organizations, affiliations, Sites, Site memberships, Site assignments, Attendance, Payroll, Expenses, Payments, and financial history.
- Derive tenant context only from authenticated state and validated middleware.
- Fail closed when normalized email maps to ambiguous identities.
- Keep `SiteMember` as the User authorization/Site-management relationship.
- Keep `SiteAssignment` as the Staff placement relationship.
- Keep Attendance and Payroll Staff-based.
- Do not infer Payroll Site attribution because `PayRunItem` has no Site relationship.
- Do not infer PayRun disbursement state because Payment has no PayRun relationship.

## Promotion Decision

**Production promotion is blocked.**

The code and local test/build gates are healthy, but release approval requires operator-owned identity and tenant reconciliation, approved database constraint rollout, shared announcement invalidation transport for multi-instance deployment, and authenticated staging browser/security evidence. Until all blockers are closed with auditable evidence, runtime fail-closed behavior and durable announcement refetch must remain enabled, and no protected historical record may be automatically altered.
