# PayMuster Final Admin Security Gate

**Assessment date:** 2026-08-19
**Gate:** Final Admin Closure Gate  
**Final verdict:** **NOT READY FOR PRODUCTION PROMOTION**  
**Admin freeze:** **ACTIVE — BLOCKED**

## 1. Executive Decision

The bounded code-level Admin closure work passed the available local verification matrix. The backend now has stronger request-time session authorization, persisted-role permission coverage, Site-derived tenant context, organization-scoped lifecycle mutations, invitation ownership checks, conditional affiliation transitions, session revocation, and Owner deletion protection.

Production promotion remains blocked. The current database and client architecture does not yet prove the required invariant of one global identity with explicit organization memberships. Duplicate normalized-email identities require human resolution, ten tenant-mismatch relationships remain in the guarded local evidence target, web and mobile refresh-token storage is not production-grade, Owner/company document review is not implemented, and no approved authenticated staging environment was available for end-to-end evidence.

No production system was contacted. No migration was applied. No protected business record was merged, deleted, reassigned, normalized, reseeded, truncated, or automatically repaired.

## 2. Gate Scope and Safety Boundary

This gate was limited to changes that could be made without human identity, ownership, company, tenant, payroll, attendance, or historical-record judgment.

The following constraints were enforced:

- Preserve Users, Organizations, Sites, affiliations, assignments, attendance, payroll, expenses, payments, documents, audit records, and financial history.
- Do not automatically merge duplicate identities or move records between organizations.
- Do not apply Prisma migrations or destructive Prisma commands.
- Do not contact production.
- Do not invalidate unrelated sessions.
- Do not fabricate staging, browser, or authenticated evidence.
- Keep platform roles separate from future organization/job roles.
- Do not implement the Owner Dashboard or Owner Portal during this gate.
- Classify any required human identity, ownership, or tenant decision as **BLOCKED — OPERATOR ACTION REQUIRED**.

Target architecture:

```text
one global identity -> many explicit organization memberships
```

Current compatibility authority remains:

```text
User.orgId + User.role + Session.orgId
```

## 3. Safe Backend Closures

### 3.1 Persisted-role permission alignment

The permission map now covers every persisted role: `SUPER_ADMIN`, `OWNER`, `ADMIN`, `SUPERVISOR`, `ACCOUNTANT`, `STAFF`, and `VIEWER`. Legacy `MANAGER` and `WORKER` mappings were removed. Unknown roles continue to receive no permissions and therefore fail closed.

Evidence: [backend/src/lib/permissions.ts](backend/src/lib/permissions.ts) and [backend/src/middlewares/permission.middleware.ts](backend/src/middlewares/permission.middleware.ts).

### 3.2 Site-derived tenant context

Site-scoped requests now load the Site, derive the authoritative organization from `Site.orgId`, reject a conflicting company header, and install the verified company and Site IDs in request context. A caller-supplied company header can confirm ownership but cannot switch the Site's tenant context.

Evidence: [backend/src/middlewares/tenant.middleware.ts](backend/src/middlewares/tenant.middleware.ts) and [backend/src/middlewares/tenant.test.ts](backend/src/middlewares/tenant.test.ts).

### 3.3 Request-time authorization revalidation

Each authenticated request revalidates the current User and persisted Session, including session revocation and expiry, User and Session organization agreement, account status, active/disabled state, and the current database role. Maintenance mode is also checked with the current role.

Evidence: [backend/src/middlewares/auth.ts](backend/src/middlewares/auth.ts) and [backend/src/middlewares/auth.test.ts](backend/src/middlewares/auth.test.ts).

### 3.4 Join and invitation transitions

Join creation now rejects already affiliated applicants inside the transaction. Join approval and rejection use organization-scoped pending-state predicates. Approval rechecks the applicant's current affiliation, conditionally assigns the organization, and revokes existing sessions.

Invitation emails are normalized for storage and lookup. Acceptance now validates pending and unexpired state, authenticated email ownership, current unaffiliated state, and conditionally updates both invitation and User. Successful acceptance revokes active sessions.

Evidence: [backend/src/services/join.service.ts](backend/src/services/join.service.ts), [backend/src/services/invitation.service.ts](backend/src/services/invitation.service.ts), and [backend/src/services/closure-gate.test.ts](backend/src/services/closure-gate.test.ts).

### 3.5 Promotion and staff lifecycle authorization

Promotion creation and approval now recheck organization affiliation transactionally. Approval cannot assign `SUPER_ADMIN`, conditionally transitions the request and User role, and revokes active sessions.

Staff role changes, suspension, restoration, and termination now recheck and mutate the target with organization-scoped predicates. These transitions revoke sessions. Termination removes current Site membership for the target organization and clears the compatibility affiliation while preserving Staff, attendance, payroll, and financial history.

Evidence: [backend/src/services/promotion.service.ts](backend/src/services/promotion.service.ts), [backend/src/services/staff.service.ts](backend/src/services/staff.service.ts), and [backend/src/services/closure-gate.test.ts](backend/src/services/closure-gate.test.ts).

### 3.6 Owner self-service deletion protection

An Owner attached to an organization can no longer use self-service deletion to dissolve the organization or unlink other Users. The operation fails before a transaction starts and requires an administrator-reviewed process. Super Admin self-deletion remains denied. Non-owner deletion remains a soft identity tombstone with target-session revocation and OTP removal.

Evidence: [backend/src/lib/auth-service.ts](backend/src/lib/auth-service.ts) and [backend/src/services/closure-gate.test.ts](backend/src/services/closure-gate.test.ts).

### 3.7 Admin mutation reaction and refresh safety

Admin list and detail fetches now use request-generation guards so an older success or error cannot overwrite a newer refresh, filter, navigation, or post-mutation result. The covered surfaces are users, Owner requests, documents, announcements/notification logs, maintenance, audit logs, dashboard metrics, company lists/details, sites, attendance, payroll, and user details.

Owner approval/rejection, document review, user lifecycle, password reset, and announcement dispatch prevent duplicate submission while a mutation is active. Owner rejection now returns dialog input before performing the screen-owned mutation and disposes its controller deterministically. Maintenance changes re-fetch the committed backend state instead of assuming the requested value became authoritative.

Evidence: [mobile/lib/features/admin/presentation](mobile/lib/features/admin/presentation), [mobile/test/features/admin/admin_users_screen_test.dart](mobile/test/features/admin/admin_users_screen_test.dart), and [mobile/test/features/admin/admin_notifications_screen_test.dart](mobile/test/features/admin/admin_notifications_screen_test.dart).

## 4. Security Classification

### 4.1 Sessions and lifecycle revocation

**Verified locally:**

- Access tokens and refresh tokens share a persisted Session UUID.
- Authenticated requests revalidate User and Session records.
- Revoked, expired, cross-organization, disabled, inactive, deleted, blocked, suspended, or rejected states fail authorization.
- Role change, suspension, deletion, password reset, invitation acceptance, join approval, promotion approval, restoration, and termination revoke relevant active sessions.
- Logout remains available during maintenance and revokes the supplied refresh-token session.

Relevant evidence: [backend/src/lib/auth-service.ts](backend/src/lib/auth-service.ts), [backend/src/middlewares/auth.ts](backend/src/middlewares/auth.ts), [backend/src/lib/auth-session.test.ts](backend/src/lib/auth-session.test.ts), and [backend/src/services/admin.service.ts](backend/src/services/admin.service.ts).

### 4.2 Maintenance mode

**Verified locally:** ordinary users fail closed during maintenance. Super Admin access remains available for recovery, including when maintenance-state resolution fails. Maintenance changes are transactional and audited.

Evidence: [backend/src/lib/maintenance-service.ts](backend/src/lib/maintenance-service.ts), [backend/src/routes/auth.ts](backend/src/routes/auth.ts), and [backend/src/lib/auth-session.test.ts](backend/src/lib/auth-session.test.ts).

### 4.3 Announcements

**Verified locally:** system and organization announcement dispatch is authenticated, permission-gated, transactionally persisted, recipient-scoped, and audited. Recipient listing and acknowledgment are User-scoped; acknowledgment uses a conditional unread-state transition.

Evidence: [backend/src/lib/announcement.service.ts](backend/src/lib/announcement.service.ts), [backend/src/routes/announcement-access.test.ts](backend/src/routes/announcement-access.test.ts), and [backend/src/controllers/announcement.controller.ts](backend/src/controllers/announcement.controller.ts).

### 4.4 Staff documents

**Verified locally:**

- Storage keys reject traversal, absolute paths, URL-like values, and malformed keys.
- Objects use the configured private Supabase bucket; public object URLs are not used.
- View URLs are signed and short-lived; the default TTL is 300 seconds.
- Uploads allow configured PDF, JPEG, and PNG MIME types and validate binary signatures.
- Database document and audit writes are atomic.
- A failed database transaction triggers compensating private-object removal.
- Recipient access is constrained by organization, Staff identity, document ID, and non-deleted state.
- Admin review routes are behind authentication and the `manage_system` permission, which is assigned only to `SUPER_ADMIN`.

Evidence: [backend/src/lib/document-storage.ts](backend/src/lib/document-storage.ts), [backend/src/services/document.service.ts](backend/src/services/document.service.ts), [backend/src/services/document.service.test.ts](backend/src/services/document.service.test.ts), and [backend/src/routes/admin.routes.ts](backend/src/routes/admin.routes.ts).

**Unresolved:** no Owner/company document-review route or approved role model is evidenced. Current document review is Super Admin-only.

### 4.5 Client token storage

**BLOCKED — OPERATOR ACTION REQUIRED**

The web client serializes access and refresh tokens into JavaScript-readable `localStorage` or `sessionStorage`. An XSS execution context can read the refresh token. Evidence: [frontend/src/lib/auth-session.ts](frontend/src/lib/auth-session.ts).

The mobile client stores access and refresh tokens in `SharedPreferences`; no platform secure-storage dependency is configured. Evidence: [mobile/lib/features/auth/data/remote_auth_provider.dart](mobile/lib/features/auth/data/remote_auth_provider.dart) and [mobile/pubspec.yaml](mobile/pubspec.yaml).

Neither storage design is approved for production promotion.

## 5. Identity and Membership Architecture

### 5.1 Current schema

The current `User` model has nullable `orgId` and nullable `email`, with organization-scoped uniqueness on `(orgId, email)`. It does not enforce one global normalized email per identity. No `OrganizationMembership` model exists.

Evidence: [backend/prisma/schema.prisma](backend/prisma/schema.prisma).

### 5.2 Duplicate normalized-email evidence

The prior guarded identity preflight identified:

- Three duplicate normalized-email groups.
- Eight verified User identities across those groups.
- Every duplicate group spans multiple organizations.
- Zero non-normalized stored email addresses.
- Zero rows changed.

Runtime email-based authentication paths fail closed on ambiguous normalized email, but runtime containment is not a database invariant and does not resolve ownership.

Evidence and migration boundary: [docs/12_Global_Email_Identity_Migration.md](docs/12_Global_Email_Identity_Migration.md).

**BLOCKED — OPERATOR ACTION REQUIRED:** operators must determine whether each duplicate represents the same human, different humans sharing an address, test data, or historical data. Credentials, Sessions, OTPs, memberships, records, and ownership must not be merged automatically.

### 5.3 Membership migration status

The additive organization-membership design is documented but not implemented. `User.orgId`, `User.role`, and `Session.orgId` remain compatibility authority. `SUPER_ADMIN` must remain a platform role and must not be granted through an organization membership.

Evidence: [docs/14_Organization_Membership_and_Owner_Evidence_Migration.md](docs/14_Organization_Membership_and_Owner_Evidence_Migration.md).

## 6. Guarded Row-Level Integrity Evidence

### 6.1 Execution controls

The final evidence mechanism is [backend/.tmp-task20-integrity.ts](backend/.tmp-task20-integrity.ts). It:

- Refuses any host other than `localhost`, `127.0.0.1`, or `::1`.
- Requires a database name explicitly containing a non-production marker such as `dev`, `test`, `stage`, or `local`.
- Executes inside a PostgreSQL transaction with `SET TRANSACTION READ ONLY`.
- Reports IDs and organization relationships only.
- Does not report names, emails, tokens, documents, or financial amounts.
- Does not mutate or repair rows.

The successful target was the local `paymuster_dev` database. Full machine-readable evidence is in [backend/.tmp-task20-integrity-output.json](backend/.tmp-task20-integrity-output.json).

### 6.2 Aggregate result

All nine missing-parent orphan categories returned zero:

| Orphan category | Count |
| --- | ---: |
| Sites missing Organization | 0 |
| SiteMembers missing parent | 0 |
| SiteAssignments missing parent | 0 |
| AttendanceRecords missing parent | 0 |
| PayCycles missing Organization | 0 |
| PayRuns missing parent | 0 |
| PayRunItems missing parent | 0 |
| Expenses missing parent | 0 |
| Payments missing parent | 0 |

Ten tenant-mismatch relationships were found across seven distinct child records:

| Relationship category | Count |
| --- | ---: |
| SiteMember to User | 2 |
| AttendanceRecord to Site | 1 |
| AttendanceRecord to Staff | 1 |
| AttendanceRecord to marker User | 2 |
| PayRun to PayCycle | 1 |
| PayRun to approver User | 2 |
| PayRunItem to Staff | 1 |
| **Total** | **10** |

All other checked mismatch categories returned zero.

### 6.3 Row-level records

| Category | Child record ID | Related record/User/Staff ID |
| --- | --- | --- |
| AttendanceRecord to marker User | `43b348e4-9d8f-46d3-b3ba-c5094cc9016a` | `daa59985-1cbc-4900-9dc8-f4fabae4f9bb` |
| AttendanceRecord to marker User | `b4105bb2-2ebd-4f73-b261-c2211065d76c` | `daa59985-1cbc-4900-9dc8-f4fabae4f9bb` |
| AttendanceRecord to Site | `43b348e4-9d8f-46d3-b3ba-c5094cc9016a` | `f76098ae-755d-43c7-b7e4-40afbc1bd6c9` |
| AttendanceRecord to Staff | `43b348e4-9d8f-46d3-b3ba-c5094cc9016a` | `f6e63d3d-27fe-4a4c-8756-3e972c10a8b2` |
| PayRunItem to Staff | `82a97b8e-6f5e-44da-adc7-5bcffbbdb824` | `f6e63d3d-27fe-4a4c-8756-3e972c10a8b2` |
| PayRun to approver User | `24d6da0e-8691-4467-8af6-c17180959135` | `daa59985-1cbc-4900-9dc8-f4fabae4f9bb` |
| PayRun to approver User | `a4b2838d-e088-445b-9b50-65b366b405dc` | `daa59985-1cbc-4900-9dc8-f4fabae4f9bb` |
| PayRun to PayCycle | `a4b2838d-e088-445b-9b50-65b366b405dc` | `089beec7-b987-4c1c-b44e-981819056b2a` |
| SiteMember to User | `67f0ce7c-4820-4545-8b0e-593c72d621f6` | `74b0b51e-12af-46f4-a566-949b08ca35ac` |
| SiteMember to User | `b460a3b5-32e4-45df-bc94-df893253cd3e` | `daa59985-1cbc-4900-9dc8-f4fabae4f9bb` |

Every row has this classification:

- Likely synthetic or historical: **UNDETERMINED — operator review required**.
- Current queries prevent exposure: **NOT PROVEN BY THIS DATABASE CHECK — verify every affected read path**.
- Operator action required: **true**.

No inference was made about the correct organization. No row was repaired.

## 7. Focused Regression Tests

New focused tests cover:

- Site middleware derives company context from verified Site ownership.
- Site middleware rejects a conflicting company header.
- Invitation acceptance rejects an authenticated account that does not own the invitation email.
- Cross-organization join rejection cannot transition the request.
- Join approval fails when the applicant became affiliated before commit.
- Staff restoration scopes lookup and mutation to the requested organization.
- Every persisted role has a permission array and legacy role mappings are absent.
- Owner self-service deletion refuses before opening a transaction.
- The Admin users screen ignores an older list response after a newer refresh completes.
- The Admin users screen renders a visible permission error and retry action instead of a blank surface.
- Successful Admin deletion sends one mutation, performs no deleted-detail re-fetch, and finishes on `/admin/users`.
- Successful Admin deletion from a directly opened nested detail route signals the retained users branch to issue a second list GET and remove the deleted identity.
- The deletion dialog requires a nonblank reason, and cancellation sends no mutation.
- Failed Admin deletion remains on the profile and renders the backend error.
- Announcement dispatch blocks duplicate submission and refreshes the durable notification log.
- A slower manual notification-log refresh cannot overwrite the newer post-dispatch durable log.

Test files: [backend/src/middlewares/tenant.test.ts](backend/src/middlewares/tenant.test.ts), [backend/src/services/closure-gate.test.ts](backend/src/services/closure-gate.test.ts), [mobile/test/features/admin/admin_users_screen_test.dart](mobile/test/features/admin/admin_users_screen_test.dart), [mobile/test/features/admin/admin_user_detail_screen_test.dart](mobile/test/features/admin/admin_user_detail_screen_test.dart), and [mobile/test/features/admin/admin_notifications_screen_test.dart](mobile/test/features/admin/admin_notifications_screen_test.dart).

The full backend suite also exercised session authorization, identity ambiguity, maintenance, announcements, Admin deletion and review transitions, documents, repositories, and Owner request concurrency. The Admin Flutter suite exercised API contracts, duplicate announcement prevention, authoritative mutation refresh behavior, deletion dialog lifecycle and navigation, payroll model parsing, and stale-response/error rendering.

## 8. Verification Matrix

| Check | Result | Evidence summary |
| --- | --- | --- |
| Prisma schema validation | **PASS** | Schema reported valid |
| Prisma client generation | **PASS** | Prisma Client 7.9.1 generated |
| Backend TypeScript build | **PASS** | `npm run build` completed |
| Backend full test suite | **PASS** | 108 passed, 0 failed |
| Backend clean production dependency audit | **PASS** | Isolated `npm ci --omit=dev --ignore-scripts` installed 149 packages from the real lockfile; `npm audit --omit=dev --audit-level=high` reported 0 vulnerabilities |
| Backend generated-client production import | **PASS** | Generated Prisma Client 7.9.1 and `@prisma/adapter-pg` loaded from the isolated production tree; `npm explain prisma --omit=dev` found no Prisma CLI dependency |
| Targeted repository whitespace check | **PASS** | `git diff --check` passed for the dependency manifests and the two corrected backend source files |
| Targeted Admin Flutter analysis | **PASS** | No issues found in the changed Admin detail, users-list refresh provider, users screen, and deletion regression test |
| Full Flutter analysis | **PASS** | No issues found in the previously completed full-package run |
| Admin Flutter test suite | **PASS** | 18 passed, including deletion lifecycle, reason/cancel, success navigation, retained nested-route list refresh, and failure-state regressions |
| Full Flutter test suite | **PASS** | 82 passed, 0 failed after the retained-route refresh regression was added |
| Frontend production build | **PASS** | 107 modules transformed; build completed |
| Flutter standard web build | **PASS** | Wasm dry run succeeded and `build/web` was produced |
| Flutter Wasm web build | **PASS** | Native Wasm compilation produced `build/web` |
| Guarded local database inventory | **PASS — READ ONLY** | Local `paymuster_dev`; zero missing-parent orphans; 10 unresolved tenant mismatches across 7 records; no rows changed by the integrity inventory |
| Admin verification synthetic cleanup | **PASS — LOCAL ONLY** | Guarded fail-closed cleanup removed exactly two detached synthetic Staff users (`26cbe415-062c-4f6e-ba0b-c84a53725f15` and `b9f36813-6f88-4e4a-af36-0c6ba8a50684`), one consumed email-verification OTP, two `USER_DELETION` notifications, and two matching `DELETE`/`User` audit rows. A guarded post-cleanup `READ ONLY` inventory against `localhost/paymuster_dev` returned zero target users and zero rows across every checked dependent relation, with zero target organizations, sites, invitations, notifications, or staff documents. Shared actor `566e673e-41b0-4a47-8924-69b63b8ba740`, shared verification fixtures, all organizations, sites, documents, business data, and unresolved tenant-mismatch rows were left untouched. |
| Unresolved local tenant-data remediation | **BLOCKED — NOT PERFORMED** | The 10 tenant mismatches across 7 records remain subject to operator investigation and approval; this synthetic-fixture cleanup did not alter them. |
| Local Admin deletion browser/CDP evidence | **PASS — SECOND POST-FIX LOCAL RUN** | The second run used the real local Flutter UI, localhost API, isolated Chrome/CDP profile, local `paymuster_dev` database, and a separately approved unattached synthetic Staff target. The protected Super Admin path disabled empty-reason submission, returned one expected 403 POST, displayed the backend error, retained the detail route and usable profile, and kept retry available. The successful path submitted a nonblank reason, returned one 200 POST, displayed the success notification, issued the automatic post-delete `/api/v1/admin/users` GET, navigated to `/admin/users`, rendered `User Management (44)`, and excluded the deleted target without a white screen, crash, stuck spinner, stale list, or broken navigation. Read-only database evidence confirmed the target as inactive, disabled, and `DELETED`, with the exact UI reason, deletion timestamp and actor, plus a matching DELETE audit recording session revocation, OTP invalidation, and preservation of organization and business history. The harness exited nonzero only because its final aggregate guard classified Chrome's expected `Failed to load resource: 403 (Forbidden)` console entry from the deliberately rejected protected request as a runtime failure; the explicit 403 functional assertions had passed and no `Runtime.exceptionThrown` event was recorded. Neither consumed synthetic target was restored or reused. |
| Authenticated staging/browser E2E | **NOT EXECUTABLE IN CURRENT ENVIRONMENT** | No approved staging origin or authenticated Admin session configured |

The Prisma CLI remains a development dependency for validation and generation. Server code imports the generated client directly, and the generated runtime declares `@prisma/client-runtime-utils` 7.9.1. The unused `@prisma/client` umbrella dependency was replaced with that exact runtime dependency after a temporary-manifest test and the real clean-install verification above. This removed the optional Prisma CLI peer from the production tree and resolved the prior `deepmerge-ts` audit findings without `npm audit fix --force` or a Prisma downgrade.

Passing local builds and tests do not override unresolved identity, schema, data, client-token, or staging-evidence blockers.

## 9. Exact Closure-Work File Inventory

The repository was already dirty. Unrelated or pre-existing worktree changes were not reverted. This list is scoped to files changed or created for the bounded closure implementation and evidence work:

### Modified

- [backend/package.json](backend/package.json)
- [backend/package-lock.json](backend/package-lock.json)
- [backend/src/server.ts](backend/src/server.ts)
- [backend/src/services/owner.service.ts](backend/src/services/owner.service.ts)
- [backend/src/lib/auth-service.ts](backend/src/lib/auth-service.ts)
- [backend/src/lib/permissions.ts](backend/src/lib/permissions.ts)
- [backend/src/middlewares/tenant.middleware.ts](backend/src/middlewares/tenant.middleware.ts)
- [backend/src/services/invitation.service.ts](backend/src/services/invitation.service.ts)
- [backend/src/services/join.service.ts](backend/src/services/join.service.ts)
- [backend/src/services/promotion.service.ts](backend/src/services/promotion.service.ts)
- [backend/src/services/staff.service.ts](backend/src/services/staff.service.ts)
- [mobile/lib/features/admin/presentation/admin_attendance_screen.dart](mobile/lib/features/admin/presentation/admin_attendance_screen.dart)
- [mobile/lib/features/admin/presentation/admin_audit_logs_screen.dart](mobile/lib/features/admin/presentation/admin_audit_logs_screen.dart)
- [mobile/lib/features/admin/presentation/admin_companies_screen.dart](mobile/lib/features/admin/presentation/admin_companies_screen.dart)
- [mobile/lib/features/admin/presentation/admin_company_detail_screen.dart](mobile/lib/features/admin/presentation/admin_company_detail_screen.dart)
- [mobile/lib/features/admin/presentation/admin_dashboard_screen.dart](mobile/lib/features/admin/presentation/admin_dashboard_screen.dart)
- [mobile/lib/features/admin/presentation/admin_documents_screen.dart](mobile/lib/features/admin/presentation/admin_documents_screen.dart)
- [mobile/lib/features/admin/presentation/admin_maintenance_screen.dart](mobile/lib/features/admin/presentation/admin_maintenance_screen.dart)
- [mobile/lib/features/admin/presentation/admin_notifications_screen.dart](mobile/lib/features/admin/presentation/admin_notifications_screen.dart)
- [mobile/lib/features/admin/presentation/admin_owner_requests_screen.dart](mobile/lib/features/admin/presentation/admin_owner_requests_screen.dart)
- [mobile/lib/features/admin/presentation/admin_payroll_screen.dart](mobile/lib/features/admin/presentation/admin_payroll_screen.dart)
- [mobile/lib/features/admin/presentation/admin_sites_screen.dart](mobile/lib/features/admin/presentation/admin_sites_screen.dart)
- [mobile/lib/features/admin/presentation/admin_user_detail_screen.dart](mobile/lib/features/admin/presentation/admin_user_detail_screen.dart)
- [mobile/lib/features/admin/presentation/admin_users_screen.dart](mobile/lib/features/admin/presentation/admin_users_screen.dart)

### Created

- [backend/src/middlewares/tenant.test.ts](backend/src/middlewares/tenant.test.ts)
- [backend/src/services/closure-gate.test.ts](backend/src/services/closure-gate.test.ts)
- [backend/.tmp-task20-integrity.ts](backend/.tmp-task20-integrity.ts)
- [backend/.tmp-task20-integrity-output.json](backend/.tmp-task20-integrity-output.json)
- [mobile/lib/features/admin/presentation/admin_users_refresh_provider.dart](mobile/lib/features/admin/presentation/admin_users_refresh_provider.dart)
- [mobile/test/features/admin/admin_notifications_screen_test.dart](mobile/test/features/admin/admin_notifications_screen_test.dart)
- [mobile/test/features/admin/admin_user_detail_screen_test.dart](mobile/test/features/admin/admin_user_detail_screen_test.dart)
- [mobile/test/features/admin/admin_users_screen_test.dart](mobile/test/features/admin/admin_users_screen_test.dart)
- [.tmp-admin-deletion-cdp.js](.tmp-admin-deletion-cdp.js)
- [PAYMUSTER_ADMIN_FINAL_SECURITY_GATE.md](PAYMUSTER_ADMIN_FINAL_SECURITY_GATE.md)

The following dirty files were inspected as security evidence but are not claimed as closure implementation edits in this inventory:

- [frontend/src/lib/auth-session.ts](frontend/src/lib/auth-session.ts)
- [mobile/lib/features/auth/data/remote_auth_provider.dart](mobile/lib/features/auth/data/remote_auth_provider.dart)

## 10. Remaining Production Blockers

1. **BLOCKED — OPERATOR ACTION REQUIRED:** global normalized-email uniqueness is not enforced by the database.
2. **BLOCKED — OPERATOR ACTION REQUIRED:** three duplicate normalized-email groups affecting eight verified identities require human resolution.
3. The schema still binds one compatibility organization and role directly to `User`, with organization-scoped email uniqueness.
4. No additive `OrganizationMembership` model, backfill, membership selection flow, or membership-bound Session migration exists.
5. **BLOCKED — OPERATOR ACTION REQUIRED:** ten tenant-mismatch relationships across seven local child records remain unresolved.
6. The database check does not prove that every read path prevents exposure of mismatched records.
7. Web refresh tokens remain readable by JavaScript through browser storage.
8. Mobile access and refresh tokens remain in `SharedPreferences` rather than platform secure storage.
9. Owner/company document review and its organization-role authorization model are not evidenced; current review is Super Admin-only.
10. Authenticated staging/browser E2E is **NOT EXECUTABLE IN CURRENT ENVIRONMENT**.
11. Production promotion and Admin freeze cannot be released while any item above remains unresolved.

## 11. Operator-Only Remediation Procedures

### 11.1 Duplicate identity resolution

1. Export the three collision groups in an approved, access-controlled operator workspace.
2. For every identity, verify the human owner, authentication methods, organization relationships, role, account status, Sessions, OTPs, and historical references.
3. Record an explicit decision for each group: distinct people, same person requiring controlled consolidation, approved test data, or approved historical retention.
4. Obtain security and data-owner approval before any mutation.
5. Use a reviewed, reversible migration for the approved decision. Never merge passwords, OAuth subjects, Sessions, or OTPs by inference.
6. Revoke only sessions affected by the approved identity transition.
7. Re-run the normalized-email preflight and require zero collisions before adding a global unique constraint.
8. Archive the decision log and before/after counts.

### 11.2 Global normalized-email migration

1. Resolve every duplicate group first.
2. Confirm zero non-normalized addresses and zero normalized collisions.
3. Decide and document null-email handling.
4. Add a canonical normalized-email representation and global unique database constraint through a reviewed migration.
5. Align Prisma schema and database constraints.
6. Verify signup, password login, Google login, verification, reset, invitation, and Admin identity paths against the new invariant.
7. Do not apply the migration automatically from this gate.

### 11.3 Tenant mismatch investigation and repair

1. Use the IDs in [backend/.tmp-task20-integrity-output.json](backend/.tmp-task20-integrity-output.json) to inspect source history, audit logs, creation path, Site/Staff/User affiliations, and payroll or attendance ownership.
2. Determine the authoritative organization for each relationship with the responsible business/data owner.
3. Review all affected read and mutation paths for cross-tenant exposure before deciding that current query scoping is sufficient.
4. Prepare a per-row remediation manifest containing current values, approved values, reason, approver, rollback values, and expected count.
5. Execute only an approved transaction with exact ID and current-value predicates; abort unless every expected count matches.
6. Preserve financial and attendance history. Reassignment or correction must not erase the original audit trail.
7. Re-run guarded row-level evidence and require zero unexplained mismatches.
8. Store before/after evidence and approvals. No automatic repair is authorized.

### 11.4 Organization membership migration

1. Resolve global identity collisions before membership backfill.
2. Approve an additive `OrganizationMembership` schema with unique `(orgId, userId)`, organization role, status, and lifecycle timestamps.
3. Keep `SUPER_ADMIN` as a platform-level role outside organization membership.
4. Backfill memberships from approved compatibility relationships without deleting `User.orgId` or `User.role` in the first phase.
5. Bind Sessions and authorization context to an explicit active membership.
6. Add membership selection and switching with explicit authorization and audit events.
7. Run dual-read reconciliation until schema and runtime evidence agree.
8. Retire compatibility fields only in a separately approved migration after rollback criteria and evidence are complete.

### 11.5 Web token migration

1. Design refresh authentication around an `HttpOnly`, `Secure`, appropriately scoped cookie with explicit `SameSite` and CSRF controls.
2. Keep short-lived access credentials out of persistent JavaScript-readable storage.
3. Define refresh rotation, replay detection, revocation, logout, device/session listing, and cookie-clearing behavior.
4. Add CSRF, XSS, refresh replay, session fixation, expiration, logout, and multi-tab tests.
5. Plan a controlled transition for existing browser sessions; do not silently keep old refresh tokens indefinitely.
6. Complete an independent security review before promotion.

### 11.6 Mobile token migration

1. Select approved platform secure storage backed by iOS Keychain and Android Keystore.
2. Define migration behavior for existing `SharedPreferences` credentials.
3. Ensure old plaintext preference values are removed only after secure persistence is confirmed.
4. Handle backup/restore, device compromise, logout, refresh rotation, storage failure, and reinstall behavior.
5. Add migration and failure-path tests on supported platforms.

### 11.7 Owner/company evidence review

1. Define whether Owner/company review is required and which organization role may perform it.
2. Define separation of duties, escalation to Super Admin, conflict-of-interest controls, and immutable audit requirements.
3. Add organization-scoped routes only after the role and tenancy model is approved.
4. Preserve private storage, signed URL, MIME/signature, and conditional review-transition controls.
5. Do not infer trust from referenced URLs or automatically fetch unapproved evidence.

### 11.8 Staging evidence

1. Provision an approved non-production environment with production-equivalent schema and security configuration.
2. Provide approved test identities for Super Admin, Owner, organization Admin, Staff, and cross-tenant negative cases.
3. Execute authenticated browser flows for authorization, maintenance, announcements, document review, role/session revocation, tenant isolation, and logout.
4. Capture request, response, audit, and UI evidence without exposing credentials or protected data.
5. Require all scenarios to pass before releasing the freeze.

## 12. Admin Freeze Checklist

- [x] Safe backend authorization and lifecycle closures implemented.
- [x] Focused regression tests added, including Admin deletion success, cancel, failure, users, and notification-log stale-response coverage.
- [x] Prisma validation and generation pass.
- [x] Backend build and 108-test suite pass.
- [x] Clean backend production install and high-severity dependency audit pass with zero vulnerabilities.
- [x] Targeted dependency/source whitespace validation passes.
- [x] Targeted and full Flutter analysis pass.
- [x] Admin 18-test suite and full 82-test Flutter suite pass.
- [x] Frontend production build passes.
- [x] Standard Flutter web build passes.
- [x] Flutter Wasm web build passes.
- [x] Guarded local/non-production read-only integrity evidence captured.
- [x] No production or staging contact, migration, automatic tenant-data repair, or mutation outside the approved local synthetic fixtures occurred; local mutations were the two approved UI soft deletions plus final removal of those two detached users, one consumed OTP, two deletion notifications, and two matching `DELETE`/`User` audit rows.
- [x] Final local Admin-verification synthetic fixture cleanup passed a guarded post-cleanup `READ ONLY` inventory.
- [ ] Global normalized-email uniqueness enforced.
- [ ] Three duplicate identity groups resolved with operator approval.
- [ ] OrganizationMembership architecture implemented and sessions membership-bound.
- [ ] Ten tenant-mismatch relationships investigated and resolved or formally accepted with proof of non-exposure.
- [ ] Web refresh tokens migrated out of JavaScript-readable persistent storage.
- [ ] Mobile tokens migrated to platform secure storage.
- [ ] Owner/company document-review model approved and verified, if required.
- [x] Final post-refresh-fix Admin deletion browser/CDP automatic list refresh verified with a separately approved synthetic fixture.
- [ ] Authenticated staging/browser E2E completed with approved credentials and environment.
- [ ] Security and data-owner sign-off recorded.
- [ ] Admin freeze released.
- [ ] Production promotion approved.

## 13. Final Verdict

# NOT READY FOR PRODUCTION PROMOTION

The locally verifiable bounded code closures, including the second post-fix local Admin deletion browser/CDP verification, are complete and the available build/test matrix passes. The release remains blocked by unresolved identity collisions, absent global identity and membership database invariants, unresolved tenant-mismatch evidence, insecure web and mobile token persistence, an unresolved Owner/company document-review requirement, and missing authenticated staging evidence.

**Admin freeze remains active. No production promotion is authorized.**
