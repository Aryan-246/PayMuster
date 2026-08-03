-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'SUSPENDED', 'BLOCKED', 'DELETED', 'INACTIVE');

-- CreateEnum
CREATE TYPE "CompanyStatus" AS ENUM ('DRAFT', 'PENDING', 'ACTIVE', 'SUSPENDED', 'DELETED');

-- CreateEnum
CREATE TYPE "DocumentStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "InvitationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'EXPIRED', 'REVOKED');

-- AlterEnum
ALTER TYPE "UserRole" ADD VALUE 'SUPER_ADMIN';

-- AlterTable
ALTER TABLE "advances" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "asset_assignments" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "assets" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "attendance_records" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "audit_logs" ADD COLUMN     "afterValue" JSONB,
ADD COLUMN     "beforeValue" JSONB,
ADD COLUMN     "browser" TEXT,
ADD COLUMN     "device" TEXT,
ADD COLUMN     "requestId" TEXT,
ADD COLUMN     "targetId" UUID;

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "correction_requests" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "expenses" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "holidays" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "material_stock" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "material_transactions" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "materials" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "organizations" DROP COLUMN "settings",
ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID,
ADD COLUMN     "joinCode" TEXT,
ADD COLUMN     "referenceCode" TEXT,
ADD COLUMN     "status" "CompanyStatus" NOT NULL DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "pay_cycles" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "pay_run_items" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "pay_runs" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "payment_approvals" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "salary_rules" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "sessions" ALTER COLUMN "orgId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "shifts" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "site_assignments" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "sites" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "staff" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "staff_documents" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID,
ADD COLUMN     "status" "DocumentStatus" NOT NULL DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "sync_queue" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "avatarUrl" TEXT,
ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID,
ADD COLUMN     "emailVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isDisabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "lastLoginAt" TIMESTAMPTZ(6),
ADD COLUMN     "provider" TEXT,
ADD COLUMN     "status" "UserStatus" NOT NULL DEFAULT 'PENDING',
ALTER COLUMN "orgId" DROP NOT NULL,
ALTER COLUMN "passwordHash" DROP NOT NULL;

-- AlterTable
ALTER TABLE "vendor_payments" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- AlterTable
ALTER TABLE "vendors" ADD COLUMN     "deleteReason" TEXT,
ADD COLUMN     "deletedBy" UUID;

-- CreateTable
CREATE TABLE "company_settings" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "theme" TEXT NOT NULL DEFAULT 'light',
    "language" TEXT NOT NULL DEFAULT 'en',
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "workingDays" JSONB,
    "attendancePolicy" JSONB,
    "payrollPolicy" JSONB,
    "featureFlags" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "company_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_join_requests" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "resolvedById" UUID,
    "resolvedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "company_join_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promotion_requests" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "requestedRole" "UserRole" NOT NULL,
    "reason" TEXT,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "resolvedById" UUID,
    "resolvedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "promotion_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "owner_requests" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "companyName" TEXT NOT NULL,
    "companyAddress" TEXT,
    "gstin" TEXT,
    "businessRegistrationUrl" TEXT,
    "identityProofUrl" TEXT,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "resolvedById" UUID,
    "resolvedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "owner_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invitations" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "status" "InvitationStatus" NOT NULL DEFAULT 'PENDING',
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "acceptedAt" TIMESTAMPTZ(6),
    "invitedById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "invitations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "company_settings_orgId_key" ON "company_settings"("orgId");

-- CreateIndex
CREATE INDEX "idx_join_req_org_id" ON "company_join_requests"("orgId");

-- CreateIndex
CREATE INDEX "idx_join_req_user_id" ON "company_join_requests"("userId");

-- CreateIndex
CREATE INDEX "idx_promo_req_org_id" ON "promotion_requests"("orgId");

-- CreateIndex
CREATE INDEX "idx_promo_req_user_id" ON "promotion_requests"("userId");

-- CreateIndex
CREATE INDEX "idx_owner_req_user_id" ON "owner_requests"("userId");

-- CreateIndex
CREATE INDEX "idx_invitations_org_id" ON "invitations"("orgId");

-- CreateIndex
CREATE INDEX "idx_invitations_email" ON "invitations"("email");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_referenceCode_key" ON "organizations"("referenceCode");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_joinCode_key" ON "organizations"("joinCode");

-- AddForeignKey
ALTER TABLE "company_settings" ADD CONSTRAINT "company_settings_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_join_requests" ADD CONSTRAINT "company_join_requests_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_join_requests" ADD CONSTRAINT "company_join_requests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promotion_requests" ADD CONSTRAINT "promotion_requests_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promotion_requests" ADD CONSTRAINT "promotion_requests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "owner_requests" ADD CONSTRAINT "owner_requests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_invitedById_fkey" FOREIGN KEY ("invitedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
