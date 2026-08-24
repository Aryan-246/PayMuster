-- Additive attendance location evidence.
-- Existing attendance records remain valid and retain their original coordinates/photos.
ALTER TABLE "attendance_records"
ADD COLUMN IF NOT EXISTS "checkInAccuracyMeters" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "checkInCapturedAt" TIMESTAMPTZ(6),
    ADD COLUMN IF NOT EXISTS "checkInDistanceMeters" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "checkInLocationValidation" TEXT,
    ADD COLUMN IF NOT EXISTS "checkOutAccuracyMeters" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "checkOutCapturedAt" TIMESTAMPTZ(6),
    ADD COLUMN IF NOT EXISTS "checkOutDistanceMeters" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "checkOutLocationValidation" TEXT;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_records_check_in_accuracy_non_negative'
) THEN
ALTER TABLE "attendance_records"
ADD CONSTRAINT "attendance_records_check_in_accuracy_non_negative" CHECK (
        "checkInAccuracyMeters" IS NULL
        OR "checkInAccuracyMeters" >= 0
    );
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_records_check_out_accuracy_non_negative'
) THEN
ALTER TABLE "attendance_records"
ADD CONSTRAINT "attendance_records_check_out_accuracy_non_negative" CHECK (
        "checkOutAccuracyMeters" IS NULL
        OR "checkOutAccuracyMeters" >= 0
    );
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_records_check_in_distance_non_negative'
) THEN
ALTER TABLE "attendance_records"
ADD CONSTRAINT "attendance_records_check_in_distance_non_negative" CHECK (
        "checkInDistanceMeters" IS NULL
        OR "checkInDistanceMeters" >= 0
    );
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'attendance_records_check_out_distance_non_negative'
) THEN
ALTER TABLE "attendance_records"
ADD CONSTRAINT "attendance_records_check_out_distance_non_negative" CHECK (
        "checkOutDistanceMeters" IS NULL
        OR "checkOutDistanceMeters" >= 0
    );
END IF;
END $$;