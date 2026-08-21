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

        return prisma.$transaction(async (tx) => {
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

            const recipients = await tx.user.findMany({
                where: {
                    ...(input.audience === 'ORGANIZATION' || input.audience === 'ROLE'
                        ? { orgId: input.orgId }
                        : {}),
                    ...(input.audience === 'ROLE' ? { role: input.audienceRole } : {}),
                    ...(input.audience === 'USER' ? { id: input.audienceUserId } : {}),
                    deletedAt: null,
                    isActive: true,
                    isDisabled: false,
                    status: { in: [...ELIGIBLE_USER_STATUSES] },
                },
                select: { id: true, orgId: true },
                orderBy: { id: 'asc' },
            });

            await tx.announcementCampaign.create({
                data: {
                    id: campaignId,
                    actorId,
                    orgId: input.orgId ?? null,
                    title: input.title,
                    body: input.body,
                    type: input.type,
                    audience: input.audience,
                    audienceRole: input.audienceRole,
                    audienceUserId: input.audienceUserId,
                    deepLink: input.deepLink,
                    recipientCount: recipients.length,
                    createdAt,
                },
            });

            if (recipients.length > 0) {
                await tx.notification.createMany({
                    data: recipients.map((recipient) => ({
                        orgId: recipient.orgId,
                        userId: recipient.id,
                        campaignId,
                        title: input.title,
                        body: input.body,
                        type: ANNOUNCEMENT_NOTIFICATION_TYPE,
                        deepLink: input.deepLink,
                    })),
                });
            }

            await tx.auditLog.create({
                data: {
                    action: 'CREATE',
                    entityType: 'AnnouncementCampaign',
                    entityId: campaignId,
                    changes: {
                        type: input.type,
                        audience: input.audience,
                        orgId: input.orgId ?? null,
                        audienceRole: input.audienceRole ?? null,
                        audienceUserId: input.audienceUserId ?? null,
                        recipientCount: recipients.length,
                        deepLink: input.deepLink ?? null,
                    },
                    userId: actorId,
                    orgId: input.orgId ?? null,
                    requestId: context.requestId,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent,
                },
            });

            return {
                campaignId,
                audience: input.audience,
                orgId: input.orgId ?? null,
                recipientCount: recipients.length,
                createdAt,
                recipientIds: recipients.map((recipient) => recipient.id),
            };
        });
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
