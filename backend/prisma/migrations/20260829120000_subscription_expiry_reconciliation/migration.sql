-- Additive index for the subscription expiry reconciliation sweep (blueprint §I):
-- the scheduled/lazy sweep filters on (status, currentPeriodEnd) across all orgs.
-- No column changes, no data mutation — index only, idempotent.
CREATE INDEX IF NOT EXISTS "idx_subscriptions_status_period_end"
ON "subscriptions"("status", "currentPeriodEnd");
