import { z } from 'zod';

export const billingWebhookSchema = z.object({}).passthrough();

export const verifyCheckoutSchema = z.object({
    orderId: z.string().trim().min(1).max(128),
    paymentId: z.string().trim().min(1).max(128),
    signature: z.string().trim().regex(/^[a-f0-9]{64}$/i),
});
