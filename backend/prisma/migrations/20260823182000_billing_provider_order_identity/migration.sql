-- Persist the external Razorpay order identity separately from provider invoice IDs.
ALTER TABLE "invoices"
ADD COLUMN IF NOT EXISTS "providerOrderId" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "uq_invoices_provider_order_id" ON "invoices"("providerOrderId");