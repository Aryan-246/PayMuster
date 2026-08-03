-- CreateEnum
CREATE TYPE "SiteRole" AS ENUM ('MANAGER', 'SUPERVISOR', 'WORKER', 'GUEST');

-- AlterEnum
BEGIN;
CREATE TYPE "SiteStatus_new" AS ENUM ('DRAFT', 'PENDING', 'ACTIVE', 'SUSPENDED', 'ARCHIVED', 'DELETED');
ALTER TABLE "sites" ALTER COLUMN "status" TYPE "SiteStatus_new" USING ("status"::text::"SiteStatus_new");
ALTER TYPE "SiteStatus" RENAME TO "SiteStatus_old";
ALTER TYPE "SiteStatus_new" RENAME TO "SiteStatus";
DROP TYPE "public"."SiteStatus_old";
COMMIT;

-- CreateTable
CREATE TABLE "site_members" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "SiteRole" NOT NULL DEFAULT 'WORKER',
    "assignedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "removedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "site_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "site_history" (
    "id" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "oldStatus" "SiteStatus",
    "newStatus" "SiteStatus" NOT NULL,
    "reason" TEXT,
    "changedById" UUID,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "site_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_sitemembers_org_id" ON "site_members"("orgId");

-- CreateIndex
CREATE INDEX "idx_sitemembers_site_id" ON "site_members"("siteId");

-- CreateIndex
CREATE INDEX "idx_sitemembers_user_id" ON "site_members"("userId");

-- CreateIndex
CREATE INDEX "idx_site_history_site_id" ON "site_history"("siteId");

-- AddForeignKey
ALTER TABLE "site_members" ADD CONSTRAINT "site_members_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_members" ADD CONSTRAINT "site_members_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_members" ADD CONSTRAINT "site_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_history" ADD CONSTRAINT "site_history_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_history" ADD CONSTRAINT "site_history_changedById_fkey" FOREIGN KEY ("changedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
