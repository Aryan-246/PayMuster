CREATE TABLE IF NOT EXISTS "auth_otps" (
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

ALTER TABLE "auth_otps"
    ADD COLUMN IF NOT EXISTS "usedAt" TIMESTAMPTZ(6),
    ADD COLUMN IF NOT EXISTS "resendCount" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS "attemptCount" INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS "idx_auth_otps_user_id" ON "auth_otps"("userId");
CREATE INDEX IF NOT EXISTS "idx_auth_otps_purpose" ON "auth_otps"("purpose");
CREATE INDEX IF NOT EXISTS "idx_auth_otps_user_purpose_created_at" ON "auth_otps"("userId", "purpose", "createdAt");

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'auth_otps_userId_fkey'
    ) THEN
        ALTER TABLE "auth_otps"
            ADD CONSTRAINT "auth_otps_userId_fkey"
            FOREIGN KEY ("userId") REFERENCES "users"("id")
            ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END $$;
