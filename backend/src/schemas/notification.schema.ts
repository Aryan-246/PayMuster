import { z } from 'zod';

export const listNotificationsQuerySchema = z
    .object({
        page: z.coerce.number().int().min(1).default(1),
        limit: z.coerce.number().int().min(1).max(100).default(50),
        unreadOnly: z
            .string()
            .optional()
            .transform((value) => value === 'true' || value === '1'),
    })
    .strict();

export const markNotificationReadParamsSchema = z
    .object({
        id: z.string().uuid(),
    })
    .strict();
