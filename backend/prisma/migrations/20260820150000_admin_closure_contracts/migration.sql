-- Admin closure contracts: additive document review metadata, private avatar keys,
-- and persistent announcement campaign targeting.
ALTER TABLE "users"
ADD COLUMN IF NOT EXISTS "avatarStorageKey" TEXT;
ALTER TABLE "staff_documents"
ADD COLUMN IF NOT EXISTS "reviewerId" UUID,
    ADD COLUMN IF NOT EXISTS "reviewedAt" TIMESTAMPTZ(6),
    ADD COLUMN IF NOT EXISTS "rejectionReason" TEXT,
    ADD COLUMN IF NOT EXISTS "version" INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS "parentDocumentId" UUID,
    ADD COLUMN IF NOT EXISTS "resubmissionCount" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS "originalFilename" TEXT,
    ADD COLUMN IF NOT EXISTS "mimeType" TEXT,
    ADD COLUMN IF NOT EXISTS "byteSize" INTEGER,
    ADD COLUMN IF NOT EXISTS "checksumSha256" TEXT;
CREATE TABLE IF NOT EXISTS "announcement_campaigns" (
    "id" UUID NOT NULL,
    "actorId" UUID NOT NULL,
    "orgId" UUID,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'INFORMATION',
    "audience" TEXT NOT NULL,
    "audienceRole" "UserRole",
    "audienceUserId" UUID,
    "deepLink" TEXT,
    "recipientCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "announcement_campaigns_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "notifications"
ADD COLUMN IF NOT EXISTS "campaignId" UUID;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'staff_documents_reviewerId_fkey'
) THEN
ALTER TABLE "staff_documents"
ADD CONSTRAINT "staff_documents_reviewerId_fkey" FOREIGN KEY ("reviewerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'staff_documents_parentDocumentId_fkey'
) THEN
ALTER TABLE "staff_documents"
ADD CONSTRAINT "staff_documents_parentDocumentId_fkey" FOREIGN KEY ("parentDocumentId") REFERENCES "staff_documents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'announcement_campaigns_actorId_fkey'
) THEN
ALTER TABLE "announcement_campaigns"
ADD CONSTRAINT "announcement_campaigns_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'announcement_campaigns_orgId_fkey'
) THEN
ALTER TABLE "announcement_campaigns"
ADD CONSTRAINT "announcement_campaigns_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'announcement_campaigns_audienceUserId_fkey'
) THEN
ALTER TABLE "announcement_campaigns"
ADD CONSTRAINT "announcement_campaigns_audienceUserId_fkey" FOREIGN KEY ("audienceUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notifications_campaignId_fkey'
) THEN
ALTER TABLE "notifications"
ADD CONSTRAINT "notifications_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "announcement_campaigns"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
END $$;
CREATE INDEX IF NOT EXISTS "idx_staff_documents_reviewer_id" ON "staff_documents"("reviewerId");
CREATE INDEX IF NOT EXISTS "idx_staff_documents_parent_id" ON "staff_documents"("parentDocumentId");
CREATE INDEX IF NOT EXISTS "idx_announcement_campaign_org_id" ON "announcement_campaigns"("orgId");
CREATE INDEX IF NOT EXISTS "idx_announcement_campaign_actor_id" ON "announcement_campaigns"("actorId");
CREATE INDEX IF NOT EXISTS "idx_announcement_campaign_user_id" ON "announcement_campaigns"("audienceUserId");
CREATE INDEX IF NOT EXISTS "idx_notifications_campaign_id" ON "notifications"("campaignId");