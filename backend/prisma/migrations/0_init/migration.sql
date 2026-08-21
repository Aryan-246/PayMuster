-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

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

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'SUPER_ADMIN', 'VIEWER');

-- CreateEnum
CREATE TYPE "AuditAction" AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'APPROVE', 'REJECT', 'PROMOTE', 'DEMOTE', 'SUSPEND', 'RESTORE', 'TERMINATE');

-- CreateEnum
CREATE TYPE "WorkerType" AS ENUM ('DAILY', 'MONTHLY', 'CONTRACT');

-- CreateEnum
CREATE TYPE "StaffStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'TERMINATED');

-- CreateEnum
CREATE TYPE "SalaryRateType" AS ENUM ('HOURLY', 'DAILY', 'MONTHLY', 'OVERTIME', 'NIGHT_SHIFT', 'HOLIDAY', 'CUSTOM');

-- CreateEnum
CREATE TYPE "SiteStatus" AS ENUM ('DRAFT', 'PENDING', 'ACTIVE', 'SUSPENDED', 'ARCHIVED', 'DELETED');

-- CreateEnum
CREATE TYPE "SiteRole" AS ENUM ('MANAGER', 'SUPERVISOR', 'WORKER', 'GUEST');

-- CreateEnum
CREATE TYPE "AttendanceStatus" AS ENUM ('PRESENT', 'ABSENT', 'HALF_DAY', 'LEAVE', 'HOLIDAY', 'OVERTIME');

-- CreateEnum
CREATE TYPE "ShiftType" AS ENUM ('REGULAR', 'NIGHT', 'DOUBLE');

-- CreateEnum
CREATE TYPE "CorrectionStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "PayCycleStatus" AS ENUM ('DRAFT', 'CALCULATED', 'APPROVED', 'PAID');

-- CreateEnum
CREATE TYPE "PaymentMode" AS ENUM ('UPI', 'BANK', 'CASH');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('DRAFT', 'APPROVED', 'PROCESSING', 'FAILED', 'PAID');

-- CreateEnum
CREATE TYPE "PaymentApprovalAction" AS ENUM ('SUBMITTED', 'APPROVED', 'REJECTED', 'FAILED');

-- CreateEnum
CREATE TYPE "AdvanceStatus" AS ENUM ('REQUESTED', 'APPROVED', 'DISBURSED', 'DEDUCTED');

-- CreateEnum
CREATE TYPE "ExpenseStatus" AS ENUM ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'REIMBURSED');

-- CreateEnum
CREATE TYPE "AssetCondition" AS ENUM ('NEW', 'GOOD', 'FAIR', 'DAMAGED', 'LOST', 'RETIRED');

-- CreateEnum
CREATE TYPE "MaterialTransactionType" AS ENUM ('INWARD', 'CONSUMPTION', 'TRANSFER', 'WASTAGE', 'RETURN');

-- CreateEnum
CREATE TYPE "SyncStatus" AS ENUM ('PENDING', 'SYNCED', 'CONFLICT', 'FAILED');

-- CreateTable
CREATE TABLE "organizations" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "referenceCode" TEXT,
    "publicId" TEXT,
    "joinCode" TEXT,
    "status" "CompanyStatus" NOT NULL DEFAULT 'PENDING',
    "logoUrl" TEXT,
    "gstin" TEXT,
    "subscriptionTier" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID,
    "status" "UserStatus" NOT NULL DEFAULT 'PENDING',
    "email" TEXT,
    "phone" TEXT,
    "passwordHash" TEXT,
    "role" "UserRole" NOT NULL,
    "firstName" TEXT,
    "lastName" TEXT,
    "provider" TEXT,
    "emailVerified" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isDisabled" BOOLEAN NOT NULL DEFAULT false,
    "avatarUrl" TEXT,
    "lastLoginAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_otps" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "otpHash" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "usedAt" TIMESTAMPTZ(6),
    "resendCount" INTEGER NOT NULL DEFAULT 0,
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "auth_otps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "orgId" UUID,
    "userId" UUID NOT NULL,
    "deviceInfo" TEXT,
    "ipAddress" TEXT,
    "refreshTokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "revokedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "orgId" UUID,
    "userId" UUID,
    "action" "AuditAction" NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" UUID NOT NULL,
    "changes" JSONB NOT NULL,
    "beforeValue" JSONB,
    "afterValue" JSONB,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "device" TEXT,
    "browser" TEXT,
    "requestId" TEXT,
    "targetId" UUID,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "phone" TEXT,
    "email" TEXT,
    "workerType" "WorkerType" NOT NULL,
    "status" "StaffStatus" NOT NULL,
    "joinDate" TIMESTAMPTZ(6),
    "bankAccountNumber" TEXT,
    "ifscCode" TEXT,
    "upiId" TEXT,
    "preferredPaymentMethod" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_documents" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "status" "DocumentStatus" NOT NULL DEFAULT 'PENDING',
    "fileUrl" TEXT NOT NULL,
    "expiryDate" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "staff_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "salary_rules" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "rateType" "SalaryRateType" NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "effectiveDate" TIMESTAMPTZ(6) NOT NULL,
    "maxAdvanceDeductionPercent" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "salary_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shifts" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "gracePeriodMins" INTEGER NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "shifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "holidays" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "date" TIMESTAMPTZ(6) NOT NULL,
    "name" TEXT NOT NULL,
    "multiplier" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "holidays_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sites" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "geoFenceRadius" INTEGER,
    "clientId" UUID,
    "startDate" TIMESTAMPTZ(6),
    "expectedEndDate" TIMESTAMPTZ(6),
    "status" "SiteStatus" NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "sites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "site_assignments" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "assignedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "removedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "site_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attendance_records" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "date" TIMESTAMPTZ(6) NOT NULL,
    "status" "AttendanceStatus" NOT NULL,
    "checkInTime" TIMESTAMPTZ(6),
    "checkOutTime" TIMESTAMPTZ(6),
    "checkInLatitude" DOUBLE PRECISION,
    "checkInLongitude" DOUBLE PRECISION,
    "checkOutLatitude" DOUBLE PRECISION,
    "checkOutLongitude" DOUBLE PRECISION,
    "checkInPhotoUrl" TEXT,
    "checkOutPhotoUrl" TEXT,
    "shiftType" "ShiftType" NOT NULL,
    "overtimeHours" DOUBLE PRECISION,
    "markedById" UUID,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "attendance_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "correction_requests" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "attendanceRecordId" UUID NOT NULL,
    "requestedById" UUID NOT NULL,
    "requestedChanges" JSONB NOT NULL,
    "reason" TEXT,
    "status" "CorrectionStatus" NOT NULL,
    "resolvedById" UUID,
    "resolvedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "correction_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pay_cycles" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "startDate" TIMESTAMPTZ(6) NOT NULL,
    "endDate" TIMESTAMPTZ(6) NOT NULL,
    "status" "PayCycleStatus" NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "pay_cycles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pay_runs" (
    "id" UUID NOT NULL,
    "publicId" TEXT,
    "orgId" UUID NOT NULL,
    "payCycleId" UUID NOT NULL,
    "totalAmount" DECIMAL(65,30) NOT NULL,
    "approvedById" UUID,
    "approvedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "pay_runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pay_run_items" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "payRunId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "grossPay" DECIMAL(65,30) NOT NULL,
    "deductions" JSONB NOT NULL,
    "additions" JSONB NOT NULL,
    "arrears" JSONB NOT NULL,
    "netPay" DECIMAL(65,30) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "pay_run_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "mode" "PaymentMode" NOT NULL,
    "referenceId" TEXT,
    "status" "PaymentStatus" NOT NULL,
    "approvedById" UUID,
    "approvedAt" TIMESTAMPTZ(6),
    "failureReason" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_approvals" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "paymentId" UUID NOT NULL,
    "action" "PaymentApprovalAction" NOT NULL,
    "actorId" UUID NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "payment_approvals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "advances" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "status" "AdvanceStatus" NOT NULL,
    "requestedAt" TIMESTAMPTZ(6),
    "approvedAt" TIMESTAMPTZ(6),
    "disbursedAt" TIMESTAMPTZ(6),
    "deductedAt" TIMESTAMPTZ(6),
    "linkedDeductionId" UUID,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "advances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "category" TEXT NOT NULL,
    "date" TIMESTAMPTZ(6) NOT NULL,
    "siteId" UUID,
    "paidById" UUID,
    "paymentMethod" TEXT NOT NULL,
    "status" "ExpenseStatus" NOT NULL,
    "receiptUrl" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assets" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "serialNumber" TEXT,
    "purchaseDate" TIMESTAMPTZ(6),
    "purchaseCost" DECIMAL(65,30),
    "condition" TEXT NOT NULL,
    "currentLocation" TEXT,
    "currentSiteId" UUID,
    "currentWorkerId" UUID,
    "status" "AssetCondition" NOT NULL,
    "photoUrl" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "asset_assignments" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "assetId" UUID NOT NULL,
    "staffId" UUID NOT NULL,
    "issuedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "returnedAt" TIMESTAMPTZ(6),
    "conditionNotes" TEXT,
    "photoUrl" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "asset_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "materials" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "unit" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_stock" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "currentQuantity" DECIMAL(65,30) NOT NULL,
    "reorderLevel" DECIMAL(65,30) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "material_stock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_transactions" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "siteId" UUID NOT NULL,
    "type" "MaterialTransactionType" NOT NULL,
    "quantity" DECIMAL(65,30) NOT NULL,
    "date" TIMESTAMPTZ(6) NOT NULL,
    "vendorId" UUID,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "material_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clients" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "contactName" TEXT,
    "contactEmail" TEXT,
    "contactPhone" TEXT,
    "gstin" TEXT,
    "billingAddress" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendors" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "contactName" TEXT,
    "contactEmail" TEXT,
    "contactPhone" TEXT,
    "gstin" TEXT,
    "bankAccountNumber" TEXT,
    "ifscCode" TEXT,
    "paymentDetails" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "vendors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_payments" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "vendorId" UUID NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "date" TIMESTAMPTZ(6) NOT NULL,
    "reference" TEXT,
    "materialTransactionId" UUID,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "vendor_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "orgId" UUID,
    "userId" UUID,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "deepLink" TEXT,
    "readAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_queue" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "userId" UUID,
    "operationType" TEXT NOT NULL,
    "tableName" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "SyncStatus" NOT NULL,
    "conflictResolution" JSONB,
    "localId" UUID,
    "serverId" UUID,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),
    "deletedBy" UUID,
    "deleteReason" TEXT,

    CONSTRAINT "sync_queue_pkey" PRIMARY KEY ("id")
);

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
    "publicId" TEXT,
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

-- CreateTable
CREATE TABLE "public_id_sequences" (
    "id" UUID NOT NULL,
    "entityType" TEXT NOT NULL,
    "prefix" TEXT NOT NULL,
    "counter" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "public_id_sequences_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "organizations_referenceCode_key" ON "organizations"("referenceCode");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_publicId_key" ON "organizations"("publicId");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_joinCode_key" ON "organizations"("joinCode");

-- CreateIndex
CREATE INDEX "idx_organizations_name" ON "organizations"("name");

-- CreateIndex
CREATE UNIQUE INDEX "users_publicId_key" ON "users"("publicId");

-- CreateIndex
CREATE INDEX "idx_users_org_id" ON "users"("orgId");

-- CreateIndex
CREATE UNIQUE INDEX "users_orgId_email_key" ON "users"("orgId", "email");

-- CreateIndex
CREATE UNIQUE INDEX "users_orgId_phone_key" ON "users"("orgId", "phone");

-- CreateIndex
CREATE INDEX "idx_auth_otps_user_id" ON "auth_otps"("userId");

-- CreateIndex
CREATE INDEX "idx_auth_otps_purpose" ON "auth_otps"("purpose");

-- CreateIndex
CREATE INDEX "idx_auth_otps_user_purpose_created_at" ON "auth_otps"("userId", "purpose", "createdAt");

-- CreateIndex
CREATE INDEX "idx_sessions_org_id" ON "sessions"("orgId");

-- CreateIndex
CREATE INDEX "idx_sessions_user_id" ON "sessions"("userId");

-- CreateIndex
CREATE INDEX "idx_sessions_expires_at" ON "sessions"("expiresAt");

-- CreateIndex
CREATE INDEX "idx_audit_logs_org_id" ON "audit_logs"("orgId");

-- CreateIndex
CREATE INDEX "idx_audit_logs_entity" ON "audit_logs"("entityType", "entityId");

-- CreateIndex
CREATE UNIQUE INDEX "staff_publicId_key" ON "staff"("publicId");

-- CreateIndex
CREATE INDEX "idx_staff_org_id" ON "staff"("orgId");

-- CreateIndex
CREATE UNIQUE INDEX "staff_orgId_email_key" ON "staff"("orgId", "email");

-- CreateIndex
CREATE UNIQUE INDEX "staff_orgId_phone_key" ON "staff"("orgId", "phone");

-- CreateIndex
CREATE INDEX "idx_staff_documents_org_id" ON "staff_documents"("orgId");

-- CreateIndex
CREATE INDEX "idx_staff_documents_staff_id" ON "staff_documents"("staffId");

-- CreateIndex
CREATE INDEX "idx_salary_rules_org_id" ON "salary_rules"("orgId");

-- CreateIndex
CREATE INDEX "idx_salary_rules_staff_id" ON "salary_rules"("staffId");

-- CreateIndex
CREATE INDEX "idx_shifts_org_id" ON "shifts"("orgId");

-- CreateIndex
CREATE INDEX "idx_holidays_org_id" ON "holidays"("orgId");

-- CreateIndex
CREATE INDEX "idx_holidays_date" ON "holidays"("date");

-- CreateIndex
CREATE UNIQUE INDEX "sites_publicId_key" ON "sites"("publicId");

-- CreateIndex
CREATE INDEX "idx_sites_org_id" ON "sites"("orgId");

-- CreateIndex
CREATE INDEX "idx_sites_client_id" ON "sites"("clientId");

-- CreateIndex
CREATE UNIQUE INDEX "site_assignments_publicId_key" ON "site_assignments"("publicId");

-- CreateIndex
CREATE INDEX "idx_site_assignments_org_id" ON "site_assignments"("orgId");

-- CreateIndex
CREATE INDEX "idx_site_assignments_site_id" ON "site_assignments"("siteId");

-- CreateIndex
CREATE INDEX "idx_site_assignments_staff_id" ON "site_assignments"("staffId");

-- CreateIndex
CREATE UNIQUE INDEX "site_assignments_siteId_staffId_assignedAt_key" ON "site_assignments"("siteId", "staffId", "assignedAt");

-- CreateIndex
CREATE UNIQUE INDEX "attendance_records_publicId_key" ON "attendance_records"("publicId");

-- CreateIndex
CREATE INDEX "idx_attendance_records_org_id" ON "attendance_records"("orgId");

-- CreateIndex
CREATE INDEX "idx_attendance_records_staff_id" ON "attendance_records"("staffId");

-- CreateIndex
CREATE INDEX "idx_attendance_records_site_id" ON "attendance_records"("siteId");

-- CreateIndex
CREATE INDEX "idx_attendance_records_date" ON "attendance_records"("date");

-- CreateIndex
CREATE INDEX "idx_correction_requests_org_id" ON "correction_requests"("orgId");

-- CreateIndex
CREATE INDEX "idx_correction_requests_attendance_record_id" ON "correction_requests"("attendanceRecordId");

-- CreateIndex
CREATE INDEX "idx_correction_requests_requested_by_id" ON "correction_requests"("requestedById");

-- CreateIndex
CREATE INDEX "idx_correction_requests_resolved_by_id" ON "correction_requests"("resolvedById");

-- CreateIndex
CREATE INDEX "idx_pay_cycles_org_id" ON "pay_cycles"("orgId");

-- CreateIndex
CREATE INDEX "idx_pay_cycles_period" ON "pay_cycles"("startDate", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "pay_runs_publicId_key" ON "pay_runs"("publicId");

-- CreateIndex
CREATE INDEX "idx_pay_runs_org_id" ON "pay_runs"("orgId");

-- CreateIndex
CREATE INDEX "idx_pay_runs_pay_cycle_id" ON "pay_runs"("payCycleId");

-- CreateIndex
CREATE INDEX "idx_pay_runs_approved_by_id" ON "pay_runs"("approvedById");

-- CreateIndex
CREATE INDEX "idx_pay_run_items_org_id" ON "pay_run_items"("orgId");

-- CreateIndex
CREATE INDEX "idx_pay_run_items_pay_run_id" ON "pay_run_items"("payRunId");

-- CreateIndex
CREATE INDEX "idx_pay_run_items_staff_id" ON "pay_run_items"("staffId");

-- CreateIndex
CREATE INDEX "idx_payments_org_id" ON "payments"("orgId");

-- CreateIndex
CREATE INDEX "idx_payments_staff_id" ON "payments"("staffId");

-- CreateIndex
CREATE INDEX "idx_payments_approved_by_id" ON "payments"("approvedById");

-- CreateIndex
CREATE INDEX "idx_payment_approvals_org_id" ON "payment_approvals"("orgId");

-- CreateIndex
CREATE INDEX "idx_payment_approvals_payment_id" ON "payment_approvals"("paymentId");

-- CreateIndex
CREATE INDEX "idx_payment_approvals_actor_id" ON "payment_approvals"("actorId");

-- CreateIndex
CREATE INDEX "idx_advances_org_id" ON "advances"("orgId");

-- CreateIndex
CREATE INDEX "idx_advances_staff_id" ON "advances"("staffId");

-- CreateIndex
CREATE INDEX "idx_expenses_org_id" ON "expenses"("orgId");

-- CreateIndex
CREATE INDEX "idx_expenses_site_id" ON "expenses"("siteId");

-- CreateIndex
CREATE INDEX "idx_expenses_paid_by_id" ON "expenses"("paidById");

-- CreateIndex
CREATE INDEX "idx_assets_org_id" ON "assets"("orgId");

-- CreateIndex
CREATE INDEX "idx_assets_current_site_id" ON "assets"("currentSiteId");

-- CreateIndex
CREATE INDEX "idx_assets_current_worker_id" ON "assets"("currentWorkerId");

-- CreateIndex
CREATE INDEX "idx_asset_assignments_org_id" ON "asset_assignments"("orgId");

-- CreateIndex
CREATE INDEX "idx_asset_assignments_asset_id" ON "asset_assignments"("assetId");

-- CreateIndex
CREATE INDEX "idx_asset_assignments_staff_id" ON "asset_assignments"("staffId");

-- CreateIndex
CREATE INDEX "idx_materials_org_id" ON "materials"("orgId");

-- CreateIndex
CREATE INDEX "idx_material_stock_org_id" ON "material_stock"("orgId");

-- CreateIndex
CREATE INDEX "idx_material_stock_material_id" ON "material_stock"("materialId");

-- CreateIndex
CREATE INDEX "idx_material_stock_site_id" ON "material_stock"("siteId");

-- CreateIndex
CREATE UNIQUE INDEX "material_stock_materialId_siteId_key" ON "material_stock"("materialId", "siteId");

-- CreateIndex
CREATE INDEX "idx_material_transactions_org_id" ON "material_transactions"("orgId");

-- CreateIndex
CREATE INDEX "idx_material_transactions_material_id" ON "material_transactions"("materialId");

-- CreateIndex
CREATE INDEX "idx_material_transactions_site_id" ON "material_transactions"("siteId");

-- CreateIndex
CREATE INDEX "idx_material_transactions_vendor_id" ON "material_transactions"("vendorId");

-- CreateIndex
CREATE INDEX "idx_clients_org_id" ON "clients"("orgId");

-- CreateIndex
CREATE INDEX "idx_vendors_org_id" ON "vendors"("orgId");

-- CreateIndex
CREATE INDEX "idx_vendor_payments_org_id" ON "vendor_payments"("orgId");

-- CreateIndex
CREATE INDEX "idx_vendor_payments_vendor_id" ON "vendor_payments"("vendorId");

-- CreateIndex
CREATE INDEX "idx_vendor_payments_material_transaction_id" ON "vendor_payments"("materialTransactionId");

-- CreateIndex
CREATE INDEX "idx_notifications_org_id" ON "notifications"("orgId");

-- CreateIndex
CREATE INDEX "idx_notifications_user_id" ON "notifications"("userId");

-- CreateIndex
CREATE INDEX "idx_sync_queue_org_id" ON "sync_queue"("orgId");

-- CreateIndex
CREATE INDEX "idx_sync_queue_user_id" ON "sync_queue"("userId");

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
CREATE UNIQUE INDEX "owner_requests_publicId_key" ON "owner_requests"("publicId");

-- CreateIndex
CREATE INDEX "idx_owner_req_user_id" ON "owner_requests"("userId");

-- CreateIndex
CREATE INDEX "idx_invitations_org_id" ON "invitations"("orgId");

-- CreateIndex
CREATE INDEX "idx_invitations_email" ON "invitations"("email");

-- CreateIndex
CREATE INDEX "idx_sitemembers_org_id" ON "site_members"("orgId");

-- CreateIndex
CREATE INDEX "idx_sitemembers_site_id" ON "site_members"("siteId");

-- CreateIndex
CREATE INDEX "idx_sitemembers_user_id" ON "site_members"("userId");

-- CreateIndex
CREATE INDEX "idx_site_history_site_id" ON "site_history"("siteId");

-- CreateIndex
CREATE UNIQUE INDEX "public_id_sequences_entityType_prefix_key" ON "public_id_sequences"("entityType", "prefix");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_otps" ADD CONSTRAINT "auth_otps_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_documents" ADD CONSTRAINT "staff_documents_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_documents" ADD CONSTRAINT "staff_documents_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salary_rules" ADD CONSTRAINT "salary_rules_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "salary_rules" ADD CONSTRAINT "salary_rules_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "holidays" ADD CONSTRAINT "holidays_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sites" ADD CONSTRAINT "sites_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sites" ADD CONSTRAINT "sites_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_assignments" ADD CONSTRAINT "site_assignments_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_assignments" ADD CONSTRAINT "site_assignments_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "site_assignments" ADD CONSTRAINT "site_assignments_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_records" ADD CONSTRAINT "attendance_records_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_records" ADD CONSTRAINT "attendance_records_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_records" ADD CONSTRAINT "attendance_records_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendance_records" ADD CONSTRAINT "attendance_records_markedById_fkey" FOREIGN KEY ("markedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "correction_requests" ADD CONSTRAINT "correction_requests_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "correction_requests" ADD CONSTRAINT "correction_requests_attendanceRecordId_fkey" FOREIGN KEY ("attendanceRecordId") REFERENCES "attendance_records"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "correction_requests" ADD CONSTRAINT "correction_requests_requestedById_fkey" FOREIGN KEY ("requestedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "correction_requests" ADD CONSTRAINT "correction_requests_resolvedById_fkey" FOREIGN KEY ("resolvedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_cycles" ADD CONSTRAINT "pay_cycles_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_runs" ADD CONSTRAINT "pay_runs_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_runs" ADD CONSTRAINT "pay_runs_payCycleId_fkey" FOREIGN KEY ("payCycleId") REFERENCES "pay_cycles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_runs" ADD CONSTRAINT "pay_runs_approvedById_fkey" FOREIGN KEY ("approvedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_run_items" ADD CONSTRAINT "pay_run_items_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_run_items" ADD CONSTRAINT "pay_run_items_payRunId_fkey" FOREIGN KEY ("payRunId") REFERENCES "pay_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pay_run_items" ADD CONSTRAINT "pay_run_items_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_approvedById_fkey" FOREIGN KEY ("approvedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_approvals" ADD CONSTRAINT "payment_approvals_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_approvals" ADD CONSTRAINT "payment_approvals_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_approvals" ADD CONSTRAINT "payment_approvals_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "advances" ADD CONSTRAINT "advances_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "advances" ADD CONSTRAINT "advances_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_paidById_fkey" FOREIGN KEY ("paidById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assets" ADD CONSTRAINT "assets_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assets" ADD CONSTRAINT "assets_currentSiteId_fkey" FOREIGN KEY ("currentSiteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assets" ADD CONSTRAINT "assets_currentWorkerId_fkey" FOREIGN KEY ("currentWorkerId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "asset_assignments" ADD CONSTRAINT "asset_assignments_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "asset_assignments" ADD CONSTRAINT "asset_assignments_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "asset_assignments" ADD CONSTRAINT "asset_assignments_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "materials" ADD CONSTRAINT "materials_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_stock" ADD CONSTRAINT "material_stock_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_stock" ADD CONSTRAINT "material_stock_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_stock" ADD CONSTRAINT "material_stock_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_transactions" ADD CONSTRAINT "material_transactions_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_transactions" ADD CONSTRAINT "material_transactions_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_transactions" ADD CONSTRAINT "material_transactions_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_transactions" ADD CONSTRAINT "material_transactions_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "clients" ADD CONSTRAINT "clients_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_payments" ADD CONSTRAINT "vendor_payments_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_payments" ADD CONSTRAINT "vendor_payments_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_payments" ADD CONSTRAINT "vendor_payments_materialTransactionId_fkey" FOREIGN KEY ("materialTransactionId") REFERENCES "material_transactions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_queue" ADD CONSTRAINT "sync_queue_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_queue" ADD CONSTRAINT "sync_queue_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

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

