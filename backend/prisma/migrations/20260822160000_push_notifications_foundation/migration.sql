-- Additive Firebase Cloud Messaging device and delivery foundation.
-- Existing notifications remain the durable in-app source of truth.
DO $$ BEGIN CREATE TYPE "PushPlatform" AS ENUM ('ANDROID', 'IOS', 'WEB');
EXCEPTION
WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN CREATE TYPE "PushDeliveryStatus" AS ENUM ('PENDING', 'SENT', 'INVALID_TOKEN', 'FAILED');
EXCEPTION
WHEN duplicate_object THEN NULL;
END $$;
CREATE TABLE IF NOT EXISTS "device_tokens" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "platform" "PushPlatform" NOT NULL,
    "appVersion" TEXT,
    "deviceId" TEXT,
    "lastSeenAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "invalidatedAt" TIMESTAMPTZ(6),
    "invalidationReason" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "device_tokens_token_key" ON "device_tokens"("token");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_device_tokens_org_user_device" ON "device_tokens"("orgId", "userId", "deviceId");
CREATE INDEX IF NOT EXISTS "idx_device_tokens_org_user" ON "device_tokens"("orgId", "userId");
CREATE INDEX IF NOT EXISTS "idx_device_tokens_user_active" ON "device_tokens"("userId", "invalidatedAt");
CREATE TABLE IF NOT EXISTS "notification_deliveries" (
    "id" UUID NOT NULL,
    "orgId" UUID NOT NULL,
    "notificationId" UUID NOT NULL,
    "deviceTokenId" UUID NOT NULL,
    "status" "PushDeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "provider" TEXT,
    "providerMessageId" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastAttemptAt" TIMESTAMPTZ(6),
    "deliveredAt" TIMESTAMPTZ(6),
    "errorCode" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "uq_notification_deliveries_notification_token" ON "notification_deliveries"("notificationId", "deviceTokenId");
CREATE INDEX IF NOT EXISTS "idx_notification_deliveries_org_status" ON "notification_deliveries"("orgId", "status");
CREATE INDEX IF NOT EXISTS "idx_notification_deliveries_notification" ON "notification_deliveries"("notificationId");
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'device_tokens_orgId_fkey'
) THEN
ALTER TABLE "device_tokens"
ADD CONSTRAINT "device_tokens_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'device_tokens_userId_fkey'
) THEN
ALTER TABLE "device_tokens"
ADD CONSTRAINT "device_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_deliveries_orgId_fkey'
) THEN
ALTER TABLE "notification_deliveries"
ADD CONSTRAINT "notification_deliveries_orgId_fkey" FOREIGN KEY ("orgId") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_deliveries_notificationId_fkey'
) THEN
ALTER TABLE "notification_deliveries"
ADD CONSTRAINT "notification_deliveries_notificationId_fkey" FOREIGN KEY ("notificationId") REFERENCES "notifications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_deliveries_deviceTokenId_fkey'
) THEN
ALTER TABLE "notification_deliveries"
ADD CONSTRAINT "notification_deliveries_deviceTokenId_fkey" FOREIGN KEY ("deviceTokenId") REFERENCES "device_tokens"("id") ON DELETE CASCADE ON UPDATE CASCADE;
END IF;
END $$;