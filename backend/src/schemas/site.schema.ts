import { z } from 'zod';

export const createSiteSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters long"),
  address: z.string().optional(),
});

export const updateSiteStatusSchema = z.object({
  status: z.enum(['DRAFT', 'PENDING', 'ACTIVE', 'SUSPENDED', 'ARCHIVED', 'DELETED']),
  reason: z.string().optional(),
});
