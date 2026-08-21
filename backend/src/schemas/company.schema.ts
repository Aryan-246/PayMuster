import { z } from 'zod';
import { UserRole } from '../../generated/prisma/index.js';

export const updateCompanySettingsSchema = z.object({
  attendanceMethod: z.string().optional(),
  payrollCycle: z.string().optional(),
  timezone: z.string().optional(),
});

export const joinRequestSchema = z.object({
  notes: z.string().optional(),
});

export const rejectRequestSchema = z.object({
  reason: z.string().optional(),
});

export const promotionRequestSchema = z.object({
  requestedRole: z.enum(['ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF']),
  reason: z.string().optional(),
});

const optionalTrimmedText = (maximum: number) =>
  z.string().trim().min(1).max(maximum).optional();

const optionalHttpsUrl = z
  .string()
  .trim()
  .url()
  .max(2048)
  .refine((value) => new URL(value).protocol === 'https:', 'Evidence links must use HTTPS.')
  .optional();

export const ownerRequestSchema = z.object({
  companyName: z.string().trim().min(2, 'Company name is required').max(120),
  companyAddress: optionalTrimmedText(500),
  gstin: optionalTrimmedText(20),
  businessRegistrationUrl: optionalHttpsUrl,
  identityProofUrl: optionalHttpsUrl,
});

export const inviteUserSchema = z.object({
  email: z.string().email(),
  role: z.enum(['ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF']),
});

export const acceptInvitationSchema = z.object({
  token: z.string(),
});
