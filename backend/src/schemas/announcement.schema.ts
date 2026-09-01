import { z } from 'zod';

const internalAppPathSchema = z
    .string()
    .trim()
    .max(300)
    .refine((value) => value.startsWith('/app/') && !value.startsWith('//'), {
        message: 'deepLink must be an internal /app path',
    });

export const dispatchAnnouncementSchema = z
    .object({
        title: z.string().trim().min(2).max(120),
        body: z.string().trim().min(2).max(2000),
        type: z.enum(['WARNING', 'EMERGENCY', 'MEETING', 'HOLIDAY', 'INFORMATION']),
        deepLink: internalAppPathSchema.optional(),
        audience: z.enum(['SYSTEM', 'ORGANIZATION', 'ROLE', 'USER']),
        orgId: z.string().uuid().optional(),
        audienceRole: z.enum(['OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'VIEWER']).optional(),
        audienceUserId: z.string().uuid().optional(),
    })
    .strict()
    .superRefine((value, context) => {
        if (value.audience === 'ORGANIZATION' && !value.orgId) {
            context.addIssue({ code: 'custom', path: ['orgId'], message: 'orgId is required for an organization announcement' });
        }
        if (value.audience === 'ROLE' && !value.orgId) {
            context.addIssue({ code: 'custom', path: ['orgId'], message: 'orgId is required for a role announcement' });
        }
        if (value.audience === 'ROLE' && !value.audienceRole) {
            context.addIssue({ code: 'custom', path: ['audienceRole'], message: 'audienceRole is required for a role announcement' });
        }
        if (value.audience === 'USER' && !value.audienceUserId) {
            context.addIssue({ code: 'custom', path: ['audienceUserId'], message: 'audienceUserId is required for a user announcement' });
        }
        if (value.audience === 'SYSTEM' && (value.orgId || value.audienceRole || value.audienceUserId)) {
            context.addIssue({ code: 'custom', path: ['audience'], message: 'System announcements cannot include a tenant, role, or user target' });
        }
        if (value.audience === 'ORGANIZATION' && (value.audienceRole || value.audienceUserId)) {
            context.addIssue({ code: 'custom', path: ['audience'], message: 'Organization announcements cannot include a role or user target' });
        }
        if (value.audience === 'ROLE' && value.audienceUserId) {
            context.addIssue({ code: 'custom', path: ['audienceUserId'], message: 'Role announcements cannot include a user target' });
        }
        if (value.audience === 'USER' && value.audienceRole) {
            context.addIssue({ code: 'custom', path: ['audienceRole'], message: 'User announcements cannot include a role target' });
        }
    });

export const listAnnouncementsQuerySchema = z
    .object({
        page: z.coerce.number().int().min(1).default(1),
        limit: z.coerce.number().int().min(1).max(100).default(50),
    })
    .strict();

export const acknowledgeAnnouncementParamsSchema = z
    .object({
        id: z.string().uuid(),
    })
    .strict();

export type DispatchAnnouncementInput = z.infer<typeof dispatchAnnouncementSchema>;

// Tenant dispatch (blueprint C2): used by OWNER/ADMIN from their own org. orgId
// is NEVER taken from the client — the service forces the actor's org — and the
// SYSTEM (platform-wide) audience is not offered.
export const tenantDispatchAnnouncementSchema = z
    .object({
        title: z.string().trim().min(2).max(120),
        body: z.string().trim().min(2).max(2000),
        type: z.enum(['WARNING', 'EMERGENCY', 'MEETING', 'HOLIDAY', 'INFORMATION']),
        deepLink: internalAppPathSchema.optional(),
        audience: z.enum(['ORGANIZATION', 'ROLE', 'USER']),
        orgId: z.string().uuid().optional(),
        audienceRole: z.enum(['OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'VIEWER']).optional(),
        audienceUserId: z.string().uuid().optional(),
    })
    .strict()
    .superRefine((value, context) => {
        if (value.audience === 'ROLE' && !value.audienceRole) {
            context.addIssue({ code: 'custom', path: ['audienceRole'], message: 'audienceRole is required for a role announcement' });
        }
        if (value.audience === 'USER' && !value.audienceUserId) {
            context.addIssue({ code: 'custom', path: ['audienceUserId'], message: 'audienceUserId is required for a user announcement' });
        }
        if (value.audience === 'ORGANIZATION' && (value.audienceRole || value.audienceUserId)) {
            context.addIssue({ code: 'custom', path: ['audience'], message: 'Organization announcements cannot include a role or user target' });
        }
        if (value.audience === 'ROLE' && value.audienceUserId) {
            context.addIssue({ code: 'custom', path: ['audienceUserId'], message: 'Role announcements cannot include a user target' });
        }
        if (value.audience === 'USER' && value.audienceRole) {
            context.addIssue({ code: 'custom', path: ['audienceRole'], message: 'User announcements cannot include a role target' });
        }
    });
