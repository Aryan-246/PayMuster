import { randomUUID } from 'node:crypto';

import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import type { DispatchAnnouncementInput } from '../schemas/announcement.schema.js';

const ANNOUNCEMENT_NOTIFICATION_TYPE = 'ANNOUNCEMENT';
const ELIGIBLE_USER_STATUSES = ['PENDING', 'VERIFIED'] as const;

interface AnnouncementActionContext {
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
}

/** Server-authoritative actor scope: non-platform actors can only ever announce within their own org. */
export interface AnnouncementActorScope {
    role: string;
    orgId: string | null;
}

// Chunked fan-out (blueprint §R): a single createMany over a whole org does not
// scale; insert in bounded batches instead.
const NOTIFICATION_CHUNK_SIZE = 500;

export interface AnnouncementInvalidation {
    userIds: string[];
    campaignId: string;
    occurredAt: string;
}

export class AnnouncementService {
    async dispatch(
        actorId: string,
        input: DispatchAnnouncementInput,
        context: AnnouncementActionContext = {},
        actorScope?: AnnouncementActorScope,
    ): Promise<{
        campaignId: string;
        audience: DispatchAnnouncementInput['audience'];
        orgId: string | null;
        recipientCount: number;
        createdAt: Date;
        recipientIds: string[];
    }> {
        const campaignId = randomUUID();
        const createdAt = new Date();

        // Server-authoritative tenant scoping (blueprint C2): a non-platform actor
        // may only announce within their own organization — any client-supplied
        // orgId is ignored and the actor's org is forced. Cross-org ROLE/USER
        // targets are structurally impossible in this branch.
        let effectiveInput = input;
        if (actorScope && actorScope.role !== 'SUPER_ADMIN') {
            if (!actorScope.orgId) {
                throw new AppError('TENANT_REQUIRED', 'An organization context is required to dispatch announcements.', 400);
            }
            if (input.audience === 'SYSTEM') {
                // SYSTEM (platform-wide) announcements stay SUPER_ADMIN-only.
                throw new AppError('UNAUTHORIZED', 'System-wide announcements are restricted to Super Admin.', 403);
            }
            effectiveInput = { ...input, orgId: actorScope.orgId };
        }

        const input2 = effectiveInput;

        return prisma.$transaction(async (tx) => {
            await this.assertAudienceTargets(tx, input2);

            const recipients = await tx.user.findMany({
                where: this.recipientWhere(input2),
                select: { id: true, orgId: true },
                orderBy: { id: 'asc' },
            });

            await tx.announcementCampaign.create({
                data: {
                    id: campaignId,
                    actorId,
                    orgId: input2.orgId ?? null,
                    title: input2.title,
                    body: input2.body,
                    type: input2.type,
                    audience: input2.audience,
                    audienceRole: input2.audienceRole,
                    audienceUserId: input2.audienceUserId,
                    deepLink: input2.deepLink,
                    recipientCount: recipients.length,
                    createdAt,
                },
            });

            if (recipients.length > 0) {
                // Chunked fan-out (§R): bounded insert batches instead of one
                // giant createMany for large orgs.
                for (let offset = 0; offset < recipients.length; offset += NOTIFICATION_CHUNK_SIZE) {
                    const chunk = recipients.slice(offset, offset + NOTIFICATION_CHUNK_SIZE);
                    await tx.notification.createMany({
                        data: chunk.map((recipient) => ({
                            orgId: recipient.orgId,
                            userId: recipient.id,
                            campaignId,
                            title: input2.title,
                            body: input2.body,
                            type: ANNOUNCEMENT_NOTIFICATION_TYPE,
                            deepLink: input2.deepLink,
                        })),
                    });
                }
            }

            await tx.auditLog.create({
                data: {
                    action: 'CREATE',
                    entityType: 'AnnouncementCampaign',
                    entityId: campaignId,
                    changes: {
                        type: input2.type,
                        audience: input2.audience,
                        orgId: input2.orgId ?? null,
                        audienceRole: input2.audienceRole ?? null,
                        audienceUserId: input2.audienceUserId ?? null,
                        recipientCount: recipients.length,
                        deepLink: input2.deepLink ?? null,
                    },
                    userId: actorId,
                    orgId: input2.orgId ?? null,
                    requestId: context.requestId,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent,
                },
            });

            return {
                campaignId,
                audience: input2.audience,
                orgId: input2.orgId ?? null,
                recipientCount: recipients.length,
                createdAt,
                recipientIds: recipients.map((recipient) => recipient.id),
            };
        });
    }

    /** Validates that the audience's referenced org/user actually exist and are reachable. */
    private async assertAudienceTargets(tx: any, input: DispatchAnnouncementInput): Promise<void> {
        if (input.audience === 'ORGANIZATION' || input.audience === 'ROLE') {
            const organization = await tx.organization.findFirst({
                where: {
                    id: input.orgId,
                    deletedAt: null,
                    status: { not: 'DELETED' },
                },
                select: { id: true },
            });
            if (!organization) {
                throw new AppError('ORGANIZATION_NOT_FOUND', 'The announcement organization is unavailable.', 404);
            }
        }

        if (input.audience === 'USER') {
            const target = await tx.user.findFirst({
                where: {
                    id: input.audienceUserId,
                    deletedAt: null,
                    isActive: true,
                    isDisabled: false,
                    status: { in: [...ELIGIBLE_USER_STATUSES] },
                    ...(input.orgId ? { orgId: input.orgId } : {}),
                },
                select: { id: true, orgId: true },
            });
            if (!target) {
                throw new AppError('ANNOUNCEMENT_TARGET_NOT_FOUND', 'The announcement user target is unavailable.', 404);
            }
        }
    }

    /** The exact recipient filter the dispatch fan-out uses — preview and dispatch can never disagree. */
    private recipientWhere(input: DispatchAnnouncementInput) {
        return {
            ...(input.audience === 'ORGANIZATION' || input.audience === 'ROLE'
                ? { orgId: input.orgId }
                : {}),
            ...(input.audience === 'ROLE' ? { role: input.audienceRole } : {}),
            ...(input.audience === 'USER' ? { id: input.audienceUserId } : {}),
            deletedAt: null,
            isActive: true,
            isDisabled: false,
            status: { in: [...ELIGIBLE_USER_STATUSES] },
        };
    }

    /**
     * Audience preview for the single announcement compose workflow: the real
     * recipient count (same filter as dispatch — never an estimate) plus a
     * sample of who would be notified. Read-only; nothing is dispatched.
     */
    async preview(
        input: DispatchAnnouncementInput,
        actorScope?: AnnouncementActorScope,
    ): Promise<{ audience: DispatchAnnouncementInput['audience']; orgId: string | null; recipientCount: number; sampleRecipients: Array<{ publicId: string | null; name: string; email: string | null }> }> {
        let effectiveInput = input;
        if (actorScope && actorScope.role !== 'SUPER_ADMIN') {
            if (!actorScope.orgId) {
                throw new AppError('TENANT_REQUIRED', 'An organization context is required to preview announcements.', 400);
            }
            if (input.audience === 'SYSTEM') {
                throw new AppError('UNAUTHORIZED', 'System-wide announcements are restricted to Super Admin.', 403);
            }
            effectiveInput = { ...input, orgId: actorScope.orgId };
        }
        const input2 = effectiveInput;

        await this.assertAudienceTargets(prisma, input2);
        const where = this.recipientWhere(input2);
        const [recipients, total] = await Promise.all([
            prisma.user.findMany({
                where,
                select: { publicId: true, firstName: true, lastName: true, email: true },
                orderBy: { createdAt: 'desc' },
                take: 10,
            }),
            prisma.user.count({ where }),
        ]);

        return {
            audience: input2.audience,
            orgId: input2.orgId ?? null,
            recipientCount: total,
            sampleRecipients: recipients.map((r) => ({
                publicId: r.publicId,
                name: `${r.firstName} ${r.lastName}`.trim(),
                email: r.email,
            })),
        };
    }

    async listForRecipient(userId: string, page: number, limit: number) {
        const skip = (page - 1) * limit;
        const where = {
            userId,
            type: ANNOUNCEMENT_NOTIFICATION_TYPE,
            deletedAt: null,
        } as const;

        const [announcements, total, unread] = await Promise.all([
            prisma.notification.findMany({
                where,
                select: {
                    id: true,
                    title: true,
                    body: true,
                    type: true,
                    deepLink: true,
                    readAt: true,
                    createdAt: true,
                    campaignId: true,
                    campaign: { select: { type: true } },
                },
                orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                skip,
                take: limit,
            }),
            prisma.notification.count({ where }),
            prisma.notification.count({ where: { ...where, readAt: null } }),
        ]);

        return { announcements, total, unread, page, totalPages: Math.ceil(total / limit) };
    }

    async acknowledge(
        userId: string,
        notificationId: string,
        context: AnnouncementActionContext = {},
    ): Promise<{ id: string; acknowledgedAt: Date; changed: boolean }> {
        return prisma.$transaction(async (tx) => {
            const announcement = await tx.notification.findFirst({
                where: {
                    id: notificationId,
                    userId,
                    type: ANNOUNCEMENT_NOTIFICATION_TYPE,
                    deletedAt: null,
                },
                select: { id: true, orgId: true, readAt: true },
            });
            if (!announcement) {
                throw new AppError('ANNOUNCEMENT_NOT_FOUND', 'Announcement not found.', 404);
            }
            if (announcement.readAt) {
                return { id: announcement.id, acknowledgedAt: announcement.readAt, changed: false };
            }

            const acknowledgedAt = new Date();
            const transition = await tx.notification.updateMany({
                where: {
                    id: notificationId,
                    userId,
                    type: ANNOUNCEMENT_NOTIFICATION_TYPE,
                    deletedAt: null,
                    readAt: null,
                },
                data: { readAt: acknowledgedAt },
            });
            if (transition.count === 1) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'Announcement',
                        entityId: notificationId,
                        changes: { acknowledged: true },
                        userId,
                        orgId: announcement.orgId,
                        targetId: userId,
                        requestId: context.requestId,
                        ipAddress: context.ipAddress,
                        userAgent: context.userAgent,
                    },
                });
                return { id: announcement.id, acknowledgedAt, changed: true };
            }

            const current = await tx.notification.findFirst({
                where: { id: notificationId, userId, type: ANNOUNCEMENT_NOTIFICATION_TYPE, deletedAt: null },
                select: { readAt: true },
            });
            if (!current?.readAt) {
                throw new AppError('ANNOUNCEMENT_ACKNOWLEDGEMENT_CONFLICT', 'Announcement acknowledgement could not be confirmed.', 409);
            }
            return { id: announcement.id, acknowledgedAt: current.readAt, changed: false };
        });
    }
}

export const announcementService = new AnnouncementService();
