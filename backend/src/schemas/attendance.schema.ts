import { z } from 'zod';

const attendanceStatusSchema = z.enum([
    'PRESENT',
    'ABSENT',
    'HALF_DAY',
    'LEAVE',
    'HOLIDAY',
    'OVERTIME',
]);

const shiftTypeSchema = z.enum(['REGULAR', 'NIGHT', 'DOUBLE']);
const dateTimeSchema = z.string().datetime({ offset: true }).transform((value) => new Date(value));

export const createAttendanceSchema = z
    .object({
        staffId: z.string().uuid(),
        siteId: z.string().uuid(),
        date: dateTimeSchema,
        status: attendanceStatusSchema,
        checkInTime: dateTimeSchema.optional(),
        checkOutTime: dateTimeSchema.optional(),
        checkInLatitude: z.number().min(-90).max(90).optional(),
        checkInLongitude: z.number().min(-180).max(180).optional(),
        checkInAccuracyMeters: z.number().min(0).max(100).optional(),
        checkInCapturedAt: dateTimeSchema.optional(),
        checkOutLatitude: z.number().min(-90).max(90).optional(),
        checkOutLongitude: z.number().min(-180).max(180).optional(),
        checkOutAccuracyMeters: z.number().min(0).max(100).optional(),
        checkOutCapturedAt: dateTimeSchema.optional(),
        checkInPhotoUrl: z.string().url().max(2048).optional(),
        checkOutPhotoUrl: z.string().url().max(2048).optional(),
        shiftType: shiftTypeSchema.default('REGULAR'),
        overtimeHours: z.number().min(0).max(24).optional(),
        notes: z.string().trim().max(500).optional(),
    })
    .strict()
    .superRefine((value, context) => {
        const hasCheckInLatitude = value.checkInLatitude !== undefined;
        const hasCheckInLongitude = value.checkInLongitude !== undefined;
        const hasCheckOutLatitude = value.checkOutLatitude !== undefined;
        const hasCheckOutLongitude = value.checkOutLongitude !== undefined;

        if (value.status === 'PRESENT' && (!hasCheckInLatitude || !hasCheckInLongitude)) {
            context.addIssue({
                code: 'custom',
                path: ['checkInLatitude'],
                message: 'Present attendance requires a server-validated check-in coordinate pair.',
            });
        }
        if (hasCheckInLatitude !== hasCheckInLongitude) {
            context.addIssue({
                code: 'custom',
                path: ['checkInLatitude'],
                message: 'Check-in latitude and longitude must be supplied together.',
            });
        }
        if (hasCheckOutLatitude !== hasCheckOutLongitude) {
            context.addIssue({
                code: 'custom',
                path: ['checkOutLatitude'],
                message: 'Check-out latitude and longitude must be supplied together.',
            });
        }
        if ((hasCheckInLatitude || hasCheckInLongitude) && !value.checkInCapturedAt) {
            context.addIssue({
                code: 'custom',
                path: ['checkInCapturedAt'],
                message: 'Check-in capture time is required when a coordinate pair is supplied.',
            });
        }
        if ((hasCheckOutLatitude || hasCheckOutLongitude) && !value.checkOutCapturedAt) {
            context.addIssue({
                code: 'custom',
                path: ['checkOutCapturedAt'],
                message: 'Check-out capture time is required when a coordinate pair is supplied.',
            });
        }
        if (value.checkInTime && value.checkOutTime && value.checkOutTime < value.checkInTime) {
            context.addIssue({
                code: 'custom',
                path: ['checkOutTime'],
                message: 'Check-out time must not be earlier than check-in time.',
            });
        }
        if (value.status !== 'OVERTIME' && value.overtimeHours != null && value.overtimeHours > 0) {
            context.addIssue({
                code: 'custom',
                path: ['overtimeHours'],
                message: 'Overtime hours require OVERTIME attendance status.',
            });
        }
    });

export const listAttendanceQuerySchema = z
    .object({
        staffId: z.string().uuid().optional(),
        siteId: z.string().uuid().optional(),
        status: attendanceStatusSchema.optional(),
        date: z.string().date().optional(),
    })
    .strict();
