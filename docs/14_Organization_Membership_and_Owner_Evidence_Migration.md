# Organization Membership and Owner Evidence Migration Plan

**Status:** Design and operator runbook only; no Prisma migration or database DDL has been generated or applied  
**Last updated:** 2026-08-17

## Decision

PayMuster must keep one global login identity per person while allowing that identity to hold independently governed roles in multiple organizations. The current `users.orgId` and `users.role` fields combine identity, organization affiliation, and authorization. They remain the supported single-company compatibility model until the staged migration in this document is reviewed and manually applied.

The target invariants are:

- `users` is the global identity and account-lifecycle table.
- One user may have zero or more organization memberships.
- A membership owns the user's role and lifecycle state within one organization.
- At most one membership exists for a given `(organization, user)` pair. A revoked membership is retained and may be explicitly reactivated; it is not replaced with a new historical identity.
- `SUPER_ADMIN` is a platform role and is never granted through an organization membership.
- Every tenant-scoped request is authorized against one active membership selected and bound to the authenticated session.
- `x-company-id` may confirm the session's selected organization but may never switch tenant context by itself.
- Organization suspension, membership suspension or revocation, account suspension, and session revocation all fail closed.
- Historical business rows, audit records, organizations, users, and Owner requests are preserved.

This plan complements the global identity invariant in `docs/12_Global_Email_Identity_Migration.md`. The global normalized-email collision gate must be resolved before duplicate identities are consolidated onto memberships.

## Current Compatibility Boundary

The current runtime supports one organization per user:

- `users.orgId` identifies the only affiliated organization.
- `users.role` provides both the global and organization role.
- `sessions.orgId` and JWT claims bind the session to that organization.
- Tenant middleware requires the requested company to equal the authenticated user's organization.
- Owner approval atomically creates an organization and changes the applicant to `OWNER` in that organization.

Do not relax these checks before membership-backed authorization is deployed. In particular, accepting any organization named by `x-company-id` would create a cross-tenant authorization defect.

## Read-Only Preflight

Run these queries against a production snapshot or read replica before preparing migration SQL. They must not be wrapped in update statements or used to repair rows automatically.

### Invalid Current Affiliations

```sql
SELECT u.id AS user_id,
       u."orgId" AS organization_id,
       u.role,
       u.status AS user_status,
       o.status AS organization_status,
       o."deletedAt" AS organization_deleted_at
FROM users u
LEFT JOIN organizations o ON o.id = u."orgId"
WHERE u."orgId" IS NOT NULL
  AND (o.id IS NULL OR o."deletedAt" IS NOT NULL)
ORDER BY u.id;
```

Every returned row requires operator review. Do not invent an organization, null the affiliation, or move the user automatically.

### Session and Identity Mismatches

```sql
SELECT s.id AS session_id,
       s."userId" AS user_id,
       s."orgId" AS session_organization_id,
       u."orgId" AS user_organization_id,
       s."revokedAt",
       s."expiresAt"
FROM sessions s
JOIN users u ON u.id = s."userId"
WHERE s."revokedAt" IS NULL
  AND s."expiresAt" > now()
  AND s."orgId" IS DISTINCT FROM u."orgId"
ORDER BY s."createdAt";
```

Any result is a security incident. Revoke affected sessions after preserving restricted diagnostic evidence; do not change user affiliations to make sessions appear valid.

### Owner and Organization Reconciliation

```sql
SELECT o.id AS organization_id,
       o.name,
       count(*) FILTER (
         WHERE u.role = 'OWNER'
           AND u."deletedAt" IS NULL
           AND u."isActive" = true
           AND u."isDisabled" = false
       ) AS active_owner_count,
       array_agg(u.id) FILTER (WHERE u.role = 'OWNER') AS owner_user_ids
FROM organizations o
LEFT JOIN users u ON u."orgId" = o.id
WHERE o."deletedAt" IS NULL
GROUP BY o.id, o.name
ORDER BY o."createdAt";
```

A zero-owner or multi-owner organization is not repaired automatically. Product policy must decide whether multiple Owners are allowed before a later constraint is considered.

### Duplicate Pending Owner Requests

```sql
SELECT "userId",
       count(*) AS pending_count,
       array_agg(id ORDER BY "createdAt") AS request_ids
FROM owner_requests
WHERE status = 'PENDING'
  AND "deletedAt" IS NULL
GROUP BY "userId"
HAVING count(*) > 1
ORDER BY pending_count DESC, "userId";
```

The application currently serializes submission per user, but historical duplicates must be resolved by an authorized reviewer before database enforcement is added.

### Global Identity Gate

Run every read-only preflight in `docs/12_Global_Email_Identity_Migration.md`. Membership backfill does not authorize automatic merging of duplicate user rows.

## Proposed Additive Schema

The first migration is additive and nullable. Names may change during implementation review, but the ownership boundaries must not.

```prisma
enum OrganizationMembershipStatus {
  ACTIVE
  SUSPENDED
  REVOKED
}

model OrganizationMembership {
  id          String                       @id @default(uuid()) @db.Uuid
  orgId       String                       @db.Uuid
  userId      String                       @db.Uuid
  role        UserRole
  status      OrganizationMembershipStatus @default(ACTIVE)
  joinedAt    DateTime                     @default(now()) @db.Timestamptz(6)
  suspendedAt DateTime?                    @db.Timestamptz(6)
  revokedAt   DateTime?                    @db.Timestamptz(6)
  createdAt   DateTime                     @default(now()) @db.Timestamptz(6)
  updatedAt   DateTime                     @updatedAt @db.Timestamptz(6)

  org      Organization @relation(fields: [orgId], references: [id], onDelete: Restrict)
  user     User         @relation(fields: [userId], references: [id], onDelete: Restrict)
  sessions Session[]

  @@unique([orgId, userId], name: "uq_organization_memberships_org_user")
  @@index([userId, status], map: "idx_organization_memberships_user_status")
  @@index([orgId, role, status], map: "idx_organization_memberships_org_role_status")
  @@map("organization_memberships")
}

model Session {
  // Existing fields remain during compatibility rollout.
  membershipId String? @db.Uuid
  membership   OrganizationMembership? @relation(fields: [membershipId], references: [id], onDelete: Restrict)

  @@index([membershipId], map: "idx_sessions_membership_id")
}
```

The reviewed SQL must add a database check that prevents `SUPER_ADMIN` in `organization_memberships.role`; Prisma's shared `UserRole` enum alone cannot express that restriction. No cascading delete may remove memberships or sessions. If pending invitation state is later represented as membership state, it requires a separate approved lifecycle design and must not weaken invitation-token validation.

## Staged Migration

### Stage 0: Preserve Runtime Containment

1. Keep `users.orgId`, `users.role`, `sessions.orgId`, JWT organization claims, and current tenant equality checks authoritative.
2. Resolve global normalized-email collisions through the audited process in the global identity runbook.
3. Run and archive the read-only preflight counts. Store sensitive IDs in a restricted operations record, not this repository.
4. Back up the database and verify restore capability.

### Stage 1: Add Nullable Structures

1. Manually apply an approved additive migration containing the membership table, enum, indexes, constraints, and nullable `sessions.membershipId`.
2. Regenerate Prisma Client and deploy code that can read the new structures but does not yet change authorization decisions.
3. Confirm existing signup, login, refresh, Owner approval, invitation, tenant, and Super Admin behavior is unchanged.

### Stage 2: Backfill Existing Affiliations

1. Insert one `ACTIVE` membership for each eligible user whose `users.orgId` references an active, non-deleted organization.
2. Copy the existing organization-scoped role exactly. Exclude `SUPER_ADMIN`; a Super Admin with an organization affiliation is a conflict requiring manual resolution.
3. Make the backfill idempotent using the `(orgId, userId)` unique constraint. Never create duplicate users, organizations, or memberships to resolve a conflict.
4. Leave unaffiliated users without memberships.
5. Reconcile row counts, roles, organization IDs, and account states. Any disagreement blocks dual-read rollout.

Backfill SQL must be generated and reviewed against the production PostgreSQL version and UUID facilities. This document intentionally does not provide an executable write statement.

### Stage 3: Dual Read and Dual Write

1. Resolve current organization access from both the legacy user tuple and the membership row.
2. While compatibility mode is active, require exact agreement among `users.orgId`, `users.role`, the active membership, `sessions.orgId`, and any `sessions.membershipId`. Missing or conflicting data returns a typed authorization error and emits a security event.
3. Update Owner approval to create the Owner membership in the same transaction as the organization, request transition, legacy user update, notification, and audit record.
4. Update invitation acceptance, join approval, role changes, suspension, restoration, termination, and account deletion to write membership state and legacy fields atomically.
5. Revoke affected sessions whenever a membership role or lifecycle state changes. New tokens must not inherit stale authorization.
6. Keep Super Admin sessions membership-free and organization-free.

### Stage 4: Session-Bound Organization Selection

1. Add an authenticated organization-list endpoint returning only active memberships and safe organization summaries.
2. Add an explicit organization-selection endpoint. It verifies account state, organization state, and active membership before rotating or issuing a session bound to `membershipId`, `orgId`, and the membership role.
3. On every authenticated request, load the session and membership from the database. JWT claims are hints to compare, not the authorization source.
4. Require `x-company-id`, when present, to equal the session-bound organization. A different header returns `TENANT_FORBIDDEN`; it never changes context.
5. Derive permissions from the session's current membership role. Do not read an organization role from global user identity fields.
6. Clear tenant-scoped caches, offline queues, local database views, and navigation state before the client opens another organization.

### Stage 5: Membership Authority

1. Enable membership-authoritative reads behind a reversible deployment flag after dual-read metrics show zero disagreements for the approved observation window.
2. Keep legacy writes active for one rollback window.
3. Run authentication, refresh, tenant isolation, role mutation, Owner approval, invitation, offline cache, and cross-organization negative tests.
4. Require read-only reconciliation to show one matching membership for every active legacy affiliation and no active session with an invalid membership.

### Stage 6: Legacy Field Retirement

This is a separate, later migration and is not authorized by this plan.

1. Stop writing `users.orgId` and organization roles to `users.role` only after every production writer is membership-aware.
2. Replace the global `users.role` meaning with an explicitly reviewed platform-role design so `SUPER_ADMIN` remains representable without assigning organization privilege.
3. Stop writing `sessions.orgId` only after all deployed clients and services use membership-bound sessions.
4. Retain legacy columns through a defined rollback and audit-retention window.
5. Drop or rename legacy columns only in a separately approved migration with verified backups and restore rehearsal.

## Authorization and Lifecycle Rules

- Account availability is global. A disabled, deleted, blocked, inactive, suspended, or rejected identity cannot use any membership.
- Membership availability is local. Suspending access in one organization must not modify other memberships.
- Organization availability is local. A suspended or deleted organization cannot be selected even when membership remains active.
- Role changes are membership changes and revoke sessions bound to that membership.
- Membership removal is a `REVOKED` transition with actor, reason, timestamps, before and after values, and audit evidence. Do not hard-delete the row.
- Owner creation and Owner role transfer require explicit policies. The migration must not infer ownership from oldest membership, organization creator, email domain, or current activity.
- All organization-scoped repositories continue to require an explicit server-validated organization ID.

## Rollback

Before membership authority is enabled, rollback consists of reverting application code while retaining the additive membership rows and nullable session references. Existing `users.orgId`, `users.role`, and `sessions.orgId` remain authoritative and unchanged.

After dual writes begin:

1. Disable organization switching.
2. Revoke sessions created or rotated with a selected membership if the previous release cannot validate them.
3. Reconcile membership and legacy tuples before reverting application code.
4. Keep membership records for diagnosis and audit; do not delete them to make reconciliation pass.

After legacy fields stop being written, rollback requires an operator-approved backfill from unambiguous active memberships. Do not attempt this automatically. If one user has multiple active memberships, an operator must select the temporary legacy organization without removing the others.

## Managed Owner Evidence: Deferred Phase

The current Owner application accepts optional HTTPS metadata in `businessRegistrationUrl` and `identityProofUrl`. This phase does not upload, copy, proxy, inspect, or attest to the referenced content. The backend must not automatically fetch these client-supplied URLs because doing so introduces server-side request forgery, redirect, malware, content-substitution, and data-residency risks.

Managed evidence upload is deferred until private storage, malware scanning, review authorization, retention, and operator migration are approved. A future additive model should use one row per object rather than adding more URL columns:

```prisma
enum OwnerEvidenceKind {
  BUSINESS_REGISTRATION
  IDENTITY_PROOF
}

model OwnerRequestEvidence {
  id               String            @id @default(uuid()) @db.Uuid
  ownerRequestId   String            @db.Uuid
  kind             OwnerEvidenceKind
  storageKey       String            @unique
  originalFilename String
  mimeType         String
  byteSize         Int
  checksumSha256   String
  uploadedBy       String            @db.Uuid
  createdAt        DateTime          @default(now()) @db.Timestamptz(6)
  deletedAt        DateTime?         @db.Timestamptz(6)

  ownerRequest OwnerRequest @relation(fields: [ownerRequestId], references: [id], onDelete: Restrict)
  uploader     User         @relation(fields: [uploadedBy], references: [id], onDelete: Restrict)

  @@index([ownerRequestId, kind], map: "idx_owner_request_evidence_request_kind")
  @@map("owner_request_evidence")
}
```

The final schema also needs review status, reviewer, rejection reason, scan status, scan engine/version, retention state, and immutable audit linkage. Those fields should reuse approved document-review semantics where practical, but Owner evidence remains a distinct authorization domain from staff documents.

### Required Upload Controls

- Private bucket only; no anonymous reads or writes.
- Backend-generated object keys; clients never choose storage paths.
- Strict byte limit, extension allowlist, MIME allowlist, and file-signature validation.
- SHA-256 checksum and immutable original metadata recorded at upload.
- Malware scan and quarantine before reviewer access.
- Short-lived signed viewing URLs issued only after Super Admin authorization and request ownership checks.
- No storage service credentials in Flutter or browser builds.
- Rate limits, upload timeouts, cleanup of failed objects, and idempotency for retries.
- Atomic evidence metadata and audit persistence, with compensating private-object deletion when database persistence fails.
- Explicit retention and legal deletion policy; soft deletion must not silently delete evidence needed for an audit or dispute.

### Evidence Migration Rules

1. Add nullable evidence structures without changing the current URL fields.
2. Deploy managed uploads for new applications and prefer managed evidence during review.
3. Inventory existing URLs without fetching them from production application workers.
4. Treat each URL as untrusted metadata. An authorized operator must verify source, ownership, content, and permission before importing any object.
5. Import approved objects through the same validation, scanning, checksum, and private-storage pipeline as new uploads.
6. Record the legacy URL only in restricted migration evidence; never use it as the managed storage key.
7. Keep URL fields for the rollback window, then retire them only through a separately approved migration after every active request is reconciled.

## Current Read-Only Owner Integrity Evidence

An aggregate preflight and restricted-detail reconciliation were run on 2026-08-17. Both executed inside PostgreSQL transactions after `SET TRANSACTION READ ONLY`. They selected lifecycle, role, affiliation, request, audit, session-count, and workload-count fields only. Email addresses, credentials, refresh-token hashes, OTP data, names, evidence URLs, and document contents were not exported. No row, schema, or migration was changed.

Clean aggregate checks:

- Zero Owner requests reference a missing user.
- Zero users reference a missing or deleted organization.
- Zero active sessions have an organization different from their current user affiliation.
- Zero pending Owner requests have an ineligible applicant.
- Zero users have more than one active pending Owner request.
- Zero active organizations have more than one active Owner.

Findings requiring operator disposition:

- Eleven active organizations have no active Owner. Nine have no active user, staff, site, attendance, or payroll workload and are consistent with empty development or historical records, but they must not be deleted or reassigned automatically.
- `PM-CMP-000013` has staff, site, attendance, and payroll records but no active Owner. Its matching approved applicant is now affiliated with another organization. This is a production-blocking affiliation ambiguity until an operator establishes the intended current Owner from restricted business evidence and audit history.
- `PM-CMP-000003` has one active non-Owner user and no staff, site, attendance, or payroll workload. Several approved requests share its normalized company name, so company-name matching is not evidence of ownership. An operator must use the request-specific approval audit organization ID and business evidence before changing any affiliation or role.
- Two approved requests no longer match current applicant state. One applicant was subsequently soft-deleted; the other remains active but was changed to `VIEWER`. Both approvals have an approval audit and an organization ID, indicating later lifecycle or role changes rather than a partial approval transaction. Preserve the approved requests as history; do not replay approval.
- Two non-deleted `OWNER` users have no organization: `PM-USR-000017` is active and has seven unrevoked, unexpired sessions, while `PM-USR-000019` is disabled and has no active session. The active account is a production blocker. An authorized operator must determine the intended affiliation and role, revoke its existing sessions during remediation, and record the decision in an audit or incident record.
- Three active `SUPER_ADMIN` users retain affiliations to pending organizations: `PM-USR-000108`, `PM-USR-000111`, and `PM-USR-000113`. None has an active session. Because platform administrators must be unaffiliated, an operator must either remove each stale affiliation or restore the intended non-platform role after verifying account ownership and history.

These findings do not show a defect in the hardened atomic Owner approval path: both mismatched approvals have organization and audit evidence, and their user state changed later. They do block production data sign-off and membership backfill because current role and affiliation tuples are not uniformly authoritative. Remediation must be an operator-reviewed, backed-up, auditable transaction followed by the same read-only checks; it must not infer ownership from company names or delete historical records to make counts pass.

## Production Gates

True multi-company context is not production-ready until:

- The global normalized-email identity gate reports zero unresolved collisions and the approved global uniqueness constraint is present.
- Every active legacy affiliation has one exactly matching membership.
- No `SUPER_ADMIN` membership exists.
- Session selection, refresh, revocation, membership suspension, role changes, and organization suspension pass fail-closed tests.
- Cross-organization requests are denied even with forged tenant headers or stale JWT claims.
- Owner approval atomically writes organization, membership, compatibility fields, notification, and audit evidence during dual-write rollout.
- Client organization switching clears tenant-scoped state and cannot expose cached data from the prior organization.
- Read-only production reconciliation remains clean for the approved observation window.

Managed Owner evidence is not production-ready until its private storage, scanning, authorization, retention, migration, and rollback gates are separately approved and tested. Until then, HTTPS fields remain optional untrusted references and must not be presented as verified documents.
