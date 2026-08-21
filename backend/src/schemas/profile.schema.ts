import { z } from 'zod';

export const updateProfileSchema = z.object({
    name: z.string().trim().min(1).max(120),
    phone: z.string().trim().max(30).nullable().optional(),
}).strict();
