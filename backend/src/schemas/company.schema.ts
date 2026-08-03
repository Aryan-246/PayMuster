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

export const ownerRequestSchema = z.object({
  businessRegistrationNumber: z.string().optional(),
});

export const inviteUserSchema = z.object({
  email: z.string().email(),
  role: z.enum(['ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF']),
});

export const acceptInvitationSchema = z.object({
  token: z.string(),
});
