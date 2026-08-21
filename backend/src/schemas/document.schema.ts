import { z } from 'zod';

export const adminDocumentParamsSchema = z
    .object({
        id: z.string().uuid(),
    })
    .strict();

export const adminDocumentVerifyBodySchema = z
    .object({})
    .strict()
    .optional()
    .default({});

export const adminDocumentRejectSchema = z
    .object({
        reason: z.string().trim().min(1, 'Rejection reason is required.').max(500),
    })
    .strict();
