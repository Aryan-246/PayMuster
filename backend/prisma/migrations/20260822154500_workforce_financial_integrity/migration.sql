-- Additive workforce financial integrity foundation.
-- Existing expense, payment, and payroll rows are preserved unchanged.
DO $$ BEGIN CREATE TYPE "AllocationType" AS ENUM ('SITE', 'COMPANY', 'PAYROLL');
EXCEPTION
WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN CREATE TYPE "ExpenseApprovalAction" AS ENUM ('SUBMITTED', 'APPROVED', 'REJECTED');
EXCEPTION
WHEN duplicate_object THEN NULL;
END $$;
CREATE TABLE IF NOT EXISTS "financial_allocations" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "amount" NUMERIC(20, 6) NOT NULL,
    "allocationType" "AllocationType" NOT NULL,
    "expenseId" UUID,
    "paymentId" UUID,
    "payRunId" UUID,
    "siteId" UUID,
    "createdById" UUID NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "financial_allocations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "financial_allocations_amount_positive" CHECK ("amount" > 0),
    CONSTRAINT "financial_allocations_one_source" CHECK (
        (
            ("expenseId" IS NOT NULL)::int + ("paymentId" IS NOT NULL)::int + ("payRunId" IS NOT NULL)::int
        ) = 1
    ),
    CONSTRAINT "financial_allocations_site_type_consistent" CHECK (
        (
            "allocationType" = 'SITE'
            AND "siteId" IS NOT NULL
        )
        OR ("allocationType" <> 'SITE')
    )
);
CREATE INDEX IF NOT EXISTS "idx_financial_allocations_org_type" ON "financial_allocations"("orgId", "allocationType");
CREATE INDEX IF NOT EXISTS "idx_financial_allocations_expense_id" ON "financial_allocations"("expenseId");
CREATE INDEX IF NOT EXISTS "idx_financial_allocations_payment_id" ON "financial_allocations"("paymentId");
CREATE INDEX IF NOT EXISTS "idx_financial_allocations_pay_run_id" ON "financial_allocations"("payRunId");
CREATE INDEX IF NOT EXISTS "idx_financial_allocations_site_id" ON "financial_allocations"("siteId");
CREATE TABLE IF NOT EXISTS "expense_approvals" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "expenseId" UUID NOT NULL,
    "action" "ExpenseApprovalAction" NOT NULL,
    "actorId" UUID NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "expense_approvals_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "idx_expense_approvals_org_expense" ON "expense_approvals"("orgId", "expenseId");
CREATE INDEX IF NOT EXISTS "idx_expense_approvals_actor_id" ON "expense_approvals"("actorId");
CREATE TABLE IF NOT EXISTS "financial_evidence" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "expenseId" UUID,
    "paymentId" UUID,
    "payRunId" UUID,
    "storageKey" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "uploadedById" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "financial_evidence_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "financial_evidence_byte_size_positive" CHECK ("byteSize" > 0),
    CONSTRAINT "financial_evidence_one_source" CHECK (
        (
            ("expenseId" IS NOT NULL)::int + ("paymentId" IS NOT NULL)::int + ("payRunId" IS NOT NULL)::int
        ) = 1
    )
);
CREATE INDEX IF NOT EXISTS "idx_financial_evidence_org_id" ON "financial_evidence"("orgId");
CREATE INDEX IF NOT EXISTS "idx_financial_evidence_expense_id" ON "financial_evidence"("expenseId");
CREATE INDEX IF NOT EXISTS "idx_financial_evidence_payment_id" ON "financial_evidence"("paymentId");
CREATE INDEX IF NOT EXISTS "idx_financial_evidence_pay_run_id" ON "financial_evidence"("payRunId");
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_orgId_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_expenseId_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_expenseId_fkey" FOREIGN KEY ("expenseId") REFERENCES "expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_paymentId_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_payRunId_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_payRunId_fkey" FOREIGN KEY ("payRunId") REFERENCES "pay_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_siteId_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_allocations_createdById_fkey'
) THEN
ALTER TABLE "financial_allocations"
ADD CONSTRAINT "financial_allocations_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'expense_approvals_orgId_fkey'
) THEN
ALTER TABLE "expense_approvals"
ADD CONSTRAINT "expense_approvals_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'expense_approvals_expenseId_fkey'
) THEN
ALTER TABLE "expense_approvals"
ADD CONSTRAINT "expense_approvals_expenseId_fkey" FOREIGN KEY ("expenseId") REFERENCES "expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'expense_approvals_actorId_fkey'
) THEN
ALTER TABLE "expense_approvals"
ADD CONSTRAINT "expense_approvals_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_evidence_orgId_fkey'
) THEN
ALTER TABLE "financial_evidence"
ADD CONSTRAINT "financial_evidence_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_evidence_expenseId_fkey'
) THEN
ALTER TABLE "financial_evidence"
ADD CONSTRAINT "financial_evidence_expenseId_fkey" FOREIGN KEY ("expenseId") REFERENCES "expenses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_evidence_paymentId_fkey'
) THEN
ALTER TABLE "financial_evidence"
ADD CONSTRAINT "financial_evidence_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_evidence_payRunId_fkey'
) THEN
ALTER TABLE "financial_evidence"
ADD CONSTRAINT "financial_evidence_payRunId_fkey" FOREIGN KEY ("payRunId") REFERENCES "pay_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'financial_evidence_uploadedById_fkey'
) THEN
ALTER TABLE "financial_evidence"
ADD CONSTRAINT "financial_evidence_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
END $$;