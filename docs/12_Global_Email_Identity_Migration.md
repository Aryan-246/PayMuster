# Global Email Identity Migration Plan

**Status:** Runtime containment implemented; database migration not applied  
**Last updated:** 2026-08-17

## Decision

PayMuster authentication treats an email address as a global login identifier. A login request does not include an organization selector, so organization-scoped email uniqueness cannot safely identify one user.

The target invariant is:

- Every non-null user email is normalized with `trim().toLowerCase()` before storage.
- One normalized email maps to at most one user identity across all organizations.
- Organization membership is separate from login identity. Future multi-company support must use a membership relation rather than duplicate user rows.
- Deleted identities retain their login identifier unless an approved retention and identity-reuse policy explicitly pseudonymizes it. Email reuse must never silently transfer access to historical business relationships.

## Current Runtime Containment

The backend now:

- Loads at most two case-insensitive matches for public email authentication operations.
- Returns `ACCOUNT_IDENTITY_CONFLICT` instead of selecting an arbitrary row when multiple identities match.
- Keeps forgot-password responses non-enumerating and sends no OTP for ambiguous identities.
- Treats every existing or ambiguous identity as already registered during signup.
- Serializes email and Google identity creation with a transaction-scoped PostgreSQL advisory lock and rechecks after acquiring it.

This prevents arbitrary-account authentication and new application-level duplicates. It does not replace a database unique constraint, because other writers could bypass the application.

## Read-Only Preflight

Run these queries against a production snapshot or production read replica before preparing migration SQL:

```sql
SELECT lower(btrim(email)) AS normalized_email,
       count(*) AS identity_count,
       array_agg(id ORDER BY "createdAt") AS user_ids,
       array_agg("orgId" ORDER BY "createdAt") AS organization_ids,
       array_agg(status ORDER BY "createdAt") AS statuses
FROM users
WHERE email IS NOT NULL
GROUP BY lower(btrim(email))
HAVING count(*) > 1
ORDER BY identity_count DESC, normalized_email;
```

```sql
SELECT id, email, lower(btrim(email)) AS normalized_email
FROM users
WHERE email IS NOT NULL
  AND email IS DISTINCT FROM lower(btrim(email));
```

The migration gate fails if either query returns unresolved rows.

## Collision Resolution

For every duplicate group, an authorized operator must identify the canonical identity using verified ownership evidence and organization records. The resolution must be reviewed and audited.

Required operator decisions:

1. Confirm whether rows represent one person, different people sharing an address, test data, or an import defect.
2. Never merge credentials, sessions, OTPs, or organization relationships automatically.
3. Revoke sessions for every affected identity before changing identity data.
4. Preserve attendance, payroll, staff, audit, and organization history.
5. If rows represent one person, move organization access to the future membership model before retiring duplicate identities.
6. If rows represent different people, assign and verify distinct addresses before either identity is re-enabled.
7. Record actor, reason, source and target IDs, before and after values, request context, and approval evidence.

## Staged Migration

The following is a plan, not an automatically executable migration.

1. Deploy runtime containment and monitor `auth.email_identity_conflict` events.
2. Run the read-only preflight and export collision IDs to a restricted incident record. Do not export password hashes, tokens, or OTPs.
3. Resolve every collision through the audited operator process.
4. Re-run the preflight and require zero collisions and zero non-normalized addresses.
5. Back up and verify restore capability.
6. In an approved transaction, normalize remaining emails and add a global unique constraint:

```sql
UPDATE users
SET email = lower(btrim(email))
WHERE email IS NOT NULL
  AND email IS DISTINCT FROM lower(btrim(email));

ALTER TABLE users
  ADD CONSTRAINT uq_users_email_global UNIQUE (email);
```

1. Update the Prisma model from organization-scoped email uniqueness to global optional email uniqueness, regenerate the client, and validate the generated migration SQL before applying it.
2. Keep organization-scoped phone uniqueness unchanged unless a separate identity decision approves global phone login.
3. Run authentication, tenant-isolation, session-revocation, Prisma, and read-only integrity gates.
4. Remove the advisory lock only after all production writers are proven to use the database constraint and the post-deployment observation window has passed.

## Rollback

If constraint creation fails, roll back the transaction and leave runtime containment active. Do not drop or rewrite user rows to force migration success.

After successful constraint creation, rollback should remove only the new constraint if a verified compatibility issue requires it. Data normalization is intentionally not reversed. Runtime ambiguity checks remain safe during rollback.

## Current Preflight Evidence

A read-only preflight was run on 2026-08-17. It found:

- Three duplicate normalized-email groups.
- Eight verified user identities across those groups.
- Every group spans multiple organizations.
- Zero non-normalized stored email addresses.
- No rows were changed.

The affected addresses and identity IDs are intentionally omitted from this repository. They must be handled in a restricted incident record. Runtime authentication is fail-closed for these groups, but database enforcement remains blocked until an authorized operator resolves them.

## Production Gate

This blocker is fully closed only when:

- Read-only preflight reports no duplicate normalized user emails.
- The approved global unique constraint exists and is validated in production.
- Prisma schema and database constraint agree.
- Email, Google, verification, reset, invitation, and administrative identity paths pass tests.
- Multi-company access uses membership records rather than duplicate user identities.
