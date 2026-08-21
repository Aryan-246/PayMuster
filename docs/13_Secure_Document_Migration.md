# Secure Staff Document Storage and Metadata Migration

## Status

This is a deployment and forward-migration runbook. No Prisma migration or database
DDL has been generated or applied by this hardening phase.

## Current Schema-Neutral Rollout

The current backend uses the existing `staff_documents.fileUrl` column as a temporary
private storage-key field. New values have this generated shape:

```text
<organization-uuid>/<staff-uuid>/<document-uuid>.<validated-extension>
```

The value is never accepted from clients and is omitted from document list responses.
Only the backend service role may upload, delete, or sign objects. The configured
Supabase bucket must be private; public bucket access defeats the authorization layer.

Legacy rows whose `fileUrl` contains an absolute URL fail closed when signed access is
requested. They must be inventoried and migrated to trusted private object keys by an
audited operator. Do not rewrite them automatically because the source object and owner
cannot be proven from a URL alone.

## Required Deployment Configuration

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (backend secret only; never ship to Flutter or browsers)
- `DOCUMENT_STORAGE_BUCKET`
- `DOCUMENT_UPLOAD_MAX_BYTES` (defaults to 10 MiB)
- `DOCUMENT_SIGNED_URL_TTL_SECONDS` (defaults to 300 seconds)
- `DOCUMENT_ALLOWED_MIME_TYPES` (supported values: PDF, JPEG, PNG)

Create the bucket as private before enabling uploads. Deny anonymous object reads and
writes. Application instances require outbound HTTPS access to Supabase Storage.

## Read-Only Preflight

Before any future migration, collect and review counts without modifying data:

```sql
SELECT
  COUNT(*) FILTER (WHERE "fileUrl" ~ '^[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\\.[A-Za-z0-9]+$') AS trusted_key_shape,
  COUNT(*) FILTER (WHERE "fileUrl" ~ '^[A-Za-z][A-Za-z0-9+.-]*://') AS legacy_absolute_url,
  COUNT(*) FILTER (WHERE "fileUrl" IS NULL OR btrim("fileUrl") = '') AS missing_location
FROM staff_documents
WHERE "deletedAt" IS NULL;
```

Also reconcile each trusted key's first two path segments with the row's `orgId` and
`staffId`, and verify object existence using a read-only storage inventory. Treat every
mismatch as an incident requiring operator review.

## Proposed Prisma Fields

A future migration should replace the overloaded location field and add immutable
upload evidence plus explicit review metadata:

```prisma
model StaffDocument {
  // Existing fields retained during backfill.
  storageKey       String?   @unique
  originalFilename String?
  mimeType          String?
  byteSize          Int?
  checksumSha256    String?
  reviewedBy        String?   @db.Uuid
  reviewedAt        DateTime? @db.Timestamptz(6)
  rejectionReason   String?

  reviewer User? @relation("StaffDocumentReviewer", fields: [reviewedBy], references: [id], onDelete: Restrict)

  @@index([orgId, staffId, status, createdAt])
  @@index([reviewedBy])
}
```

Add the inverse reviewer relation to `User`. Use a database type capable of sizes above
2 GiB if larger uploads may ever be supported; the current bounded upload permits `Int`.

## Staged Migration Plan

1. Add nullable fields and indexes only; do not remove or reinterpret `fileUrl` yet.
2. Deploy dual-read code that prefers `storageKey` and accepts `fileUrl` only when it
   passes the trusted private-key validator.
3. Backfill trusted key-shaped rows in audited batches. Derive metadata only from the
   private object itself; never trust legacy client values.
4. Quarantine absolute URLs and ownership/path mismatches for manual resolution.
5. Deploy dual-write code for the new metadata fields and reviewer fields.
6. Verify no active row lacks `storageKey`, MIME type, byte size, and checksum.
7. Add non-null and checksum/size constraints after evidence confirms readiness.
8. Stop reading `fileUrl`; retain it for a defined rollback window before a separately
   approved removal migration.

## Review and Notification Semantics

Until the migration is applied, rejection reason and reviewer evidence are preserved in
the atomic audit log. New rejection writes do not misuse the soft-deletion
`deleteReason` field. Status transition, audit record, and notification are committed in
one database transaction. If staff email does not resolve to exactly one active user in
the same organization, no notification recipient is guessed and the audit record marks
notification delivery as false.

## Rollback

Disabling the document routes or removing storage credentials makes storage operations
fail closed and does not affect existing business rows. Do not make the bucket public as
a rollback. If a deployment must be reverted, retain private objects and database rows,
then restore the previous application version after assessing whether it could expose
raw `fileUrl` values.
