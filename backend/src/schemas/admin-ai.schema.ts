import { z } from 'zod';

export const adminAiChatSchema = z
    .object({
        prompt: z
            .string()
            .trim()
            .min(1, 'Prompt is required')
            .max(2_000, 'Prompt must be 2,000 characters or fewer'),
    })
    .strict();

export const adminAiProviderResponseSchema = z
    .object({
        message: z
            .string()
            .trim()
            .min(1, 'AI response message is required')
            .max(4_000, 'AI response message is too long'),
    })
    .strict();

export type AdminAiChatInput = z.infer<typeof adminAiChatSchema>;
export type AdminAiProviderResponse = z.infer<typeof adminAiProviderResponseSchema>;
