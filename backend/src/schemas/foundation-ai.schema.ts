import { z } from 'zod';

export const foundationAiRequestSchema = z.object({
    prompt: z.string().trim().min(1).max(2_000),
}).strict();

export const foundationAiOperationSchema = z.enum(['analyze', 'summary', 'insights', 'query']);
export type FoundationAiOperation = z.infer<typeof foundationAiOperationSchema>;
