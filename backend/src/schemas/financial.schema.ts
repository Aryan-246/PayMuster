import { z } from 'zod';

// Financial amounts travel as decimal STRINGS end-to-end so the exact scale a
// client sends (including trailing zeros) is preserved into the Decimal column.
// This mirrors the accept-pattern in FinancialIntegrityService.assertPositiveDecimal;
// the service remains the sole authority on positivity (rejecting "0"/"0.00").
const decimalAmountSchema = z
    .string()
    .trim()
    .regex(
        /^(?:0|[1-9]\d*)(?:\.\d{1,6})?$/,
        'Amount must be a non-negative decimal string with up to six fractional digits.',
    );

const notesSchema = z.string().trim().max(1000).optional();

// Shape/format guard only. Cross-field business rules — exactly one source,
// SITE<->siteId coupling, and cross-tenant existence — are enforced (and tested)
// in FinancialIntegrityService, which stays the single source of truth.
export const createAllocationSchema = z
    .object({
        amount: decimalAmountSchema,
        allocationType: z.enum(['SITE', 'COMPANY', 'PAYROLL']),
        expenseId: z.string().uuid().optional(),
        paymentId: z.string().uuid().optional(),
        payRunId: z.string().uuid().optional(),
        siteId: z.string().uuid().optional(),
        notes: notesSchema,
    })
    .strict();

export const appendExpenseApprovalSchema = z
    .object({
        expenseId: z.string().uuid(),
        action: z.enum(['SUBMITTED', 'APPROVED', 'REJECTED']),
        notes: notesSchema,
    })
    .strict();

export const attachEvidenceSchema = z
    .object({
        expenseId: z.string().uuid().optional(),
        paymentId: z.string().uuid().optional(),
        payRunId: z.string().uuid().optional(),
        storageKey: z.string().trim().min(1).max(1024),
        sha256: z.string().regex(/^[a-f0-9]{64}$/i, 'sha256 must be a 64-character hex digest.'),
        mimeType: z.string().trim().min(1).max(255),
        byteSize: z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
    })
    .strict();

export const listPaymentsQuerySchema = z
    .object({
        staffId: z.string().uuid().optional(),
        status: z.enum(['DRAFT', 'APPROVED', 'PROCESSING', 'FAILED', 'PAID']).optional(),
        page: z.coerce.number().int().min(1).default(1),
        limit: z.coerce.number().int().min(1).max(100).default(50),
    })
    .strict();

export const listExpensesQuerySchema = z
    .object({
        siteId: z.string().uuid().optional(),
        status: z
            .enum(['DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'REIMBURSED'])
            .optional(),
        category: z.string().trim().max(80).optional(),
        page: z.coerce.number().int().min(1).default(1),
        limit: z.coerce.number().int().min(1).max(100).default(50),
    })
    .strict();
