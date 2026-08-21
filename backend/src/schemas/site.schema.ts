import { z } from 'zod';

export const siteStatusSchema = z.enum([
  'DRAFT',
  'PENDING',
  'ACTIVE',
  'SUSPENDED',
  'ARCHIVED',
  'DELETED',
]);

export const siteRoleSchema = z.enum([
  'MANAGER',
  'SUPERVISOR',
  'WORKER',
  'GUEST',
]);

export const createSiteSchema = z
  .object({
    name: z.string().trim().min(2).max(120),
    address: z.string().trim().max(500).optional(),
  })
  .strict();

export const updateSiteStatusSchema = z
  .object({
    status: siteStatusSchema,
    reason: z.string().trim().min(2).max(500).optional(),
  })
  .strict();

export const assignSiteMemberSchema = z
  .object({
    userId: z.string().uuid(),
    role: siteRoleSchema,
  })
  .strict();

export const listSitesQuerySchema = z
  .object({
    status: siteStatusSchema.optional(),
  })
  .strict();
