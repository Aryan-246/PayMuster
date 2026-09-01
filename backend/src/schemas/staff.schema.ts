import { z } from 'zod';

export const workerTypeSchema = z.enum(['DAILY', 'MONTHLY', 'CONTRACT']);
export const staffStatusSchema = z.enum(['ACTIVE', 'INACTIVE', 'TERMINATED']);
export const paymentMethodSchema = z.enum(['UPI', 'BANK', 'CASH']);

// POST /api/v1/staff — manual worker add by an OWNER/ADMIN (owner.txt staff
// section). Bank details are optional at creation; the mobile UI treats a
// worker without them as "verification pending".
export const createStaffSchema = z
    .object({
        firstName: z.string().trim().min(1).max(80),
        lastName: z.string().trim().min(1).max(80),
        phone: z.string().trim().min(6).max(20),
        email: z.string().trim().email().max(160).optional(),
        workerType: workerTypeSchema,
        joinDate: z.coerce.date().optional(),
        bankAccountNumber: z.string().trim().min(4).max(34).optional(),
        ifscCode: z.string().trim().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'IFSC code is invalid').optional(),
        upiId: z.string().trim().min(3).max(100).optional(),
        preferredPaymentMethod: paymentMethodSchema.optional(),
    })
    .strict()
    .superRefine((value, context) => {
        if (value.ifscCode && !value.bankAccountNumber) {
            context.addIssue({
                code: 'custom',
                path: ['bankAccountNumber'],
                message: 'bankAccountNumber is required when ifscCode is provided',
            });
        }
    });

export const staffIdParamsSchema = z
    .object({
        id: z.string().uuid(),
    })
    .strict();

export const listStaffDocumentsQuerySchema = z
    .object({
        status: z
            .enum(['UPLOADED', 'PENDING', 'PENDING_REVIEW', 'UNDER_REVIEW', 'APPROVED', 'VERIFIED', 'REJECTED', 'EXPIRED'])
            .optional(),
    })
    .strict();

export const reviewStaffDocumentParamsSchema = z
    .object({
        id: z.string().uuid(),
        documentId: z.string().uuid(),
    })
    .strict();

export const reviewStaffDocumentSchema = z
    .object({
        action: z.enum(['APPROVED', 'REJECTED', 'VERIFIED']),
        reason: z.string().trim().max(500).optional(),
    })
    .strict()
    .superRefine((value, context) => {
        if (value.action === 'REJECTED' && !value.reason) {
            context.addIssue({
                code: 'custom',
                path: ['reason'],
                message: 'A rejection reason is required',
            });
        }
    });
