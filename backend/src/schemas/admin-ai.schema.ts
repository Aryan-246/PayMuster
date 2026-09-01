import { z } from 'zod';

export const adminAiChatSchema = z
    .object({
        prompt: z
            .string()
            .trim()
            .min(1, 'Prompt is required')
            .max(2_000, 'Prompt must be 2,000 characters or fewer'),
        // Confirmation token returned by a previous AI response that required
        // explicit admin approval for a destructive operation. Executing the
        // operation is only possible with a valid, single-use token.
        confirmationToken: z.string().uuid().optional(),
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
