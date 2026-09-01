-- Mail Supply durable idempotency + history anchor (blueprint §J).
-- Additive only: new table, no changes to existing tables.
CREATE TABLE IF NOT EXISTS "mail_dispatches" (
    "id" UUID NOT NULL,
    "orgId" UUID,
    "idempotencyKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "subject" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetRole" TEXT,
    "targetUserId" UUID,
    "recipientCount" INTEGER NOT NULL DEFAULT 0,
    "sent" INTEGER NOT NULL DEFAULT 0,
    "failed" INTEGER NOT NULL DEFAULT 0,
    "blocked" INTEGER NOT NULL DEFAULT 0,
    "actorId" UUID,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "mail_dispatches_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "mail_dispatches_idempotencyKey_key" ON "mail_dispatches"("idempotencyKey");
CREATE INDEX IF NOT EXISTS "idx_mail_dispatch_org_created" ON "mail_dispatches"("orgId", "createdAt");
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'mail_dispatches_orgId_fkey'
) THEN
    ALTER TABLE "mail_dispatches" ADD CONSTRAINT "mail_dispatches_orgId_fkey"
    FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF; END $$;
