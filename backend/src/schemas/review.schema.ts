import { z } from 'zod';

export const adminReviewParamsSchema = z
    .object({
        id: z.string().uuid(),
    })
    .strict();

export const adminReviewModerateSchema = z
    .object({
        action: z.enum(['PUBLISH', 'HIDE', 'FLAG', 'RESPOND']),
        response: z.string().trim().max(2000).optional(),
    })
    .strict()
    .superRefine((value, context) => {
        if (value.action === 'RESPOND' && !value.response) {
            context.addIssue({ code: 'custom', path: ['response'], message: 'response is required for the RESPOND action' });
        }
    });
