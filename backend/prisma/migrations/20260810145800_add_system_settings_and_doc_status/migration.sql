-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "DocumentStatus" ADD VALUE 'UPLOADED';
ALTER TYPE "DocumentStatus" ADD VALUE 'PENDING_REVIEW';
ALTER TYPE "DocumentStatus" ADD VALUE 'UNDER_REVIEW';
ALTER TYPE "DocumentStatus" ADD VALUE 'VERIFIED';

-- CreateTable
CREATE TABLE "system_settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedBy" UUID,

    CONSTRAINT "system_settings_pkey" PRIMARY KEY ("key")
);

