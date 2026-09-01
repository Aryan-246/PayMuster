import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { logger } from '../lib/logger.js';

type DatabaseClient = typeof prisma;

const NOTIFICATION_SELECT = {
    id: true,
    orgId: true,
    title: true,
    body: true,
    type: true,
    deepLink: true,
    readAt: true,
    createdAt: true,
} as const;

export interface ListNotificationsOptions {
    page: number;
    limit: number;
    unreadOnly: boolean;
}

/**
 * The recipient's notification center. Every query is scoped to
 * `userId` AND the actor's org so a user can only ever see their own
 * notifications inside their current company — the org filter is applied
 * server-side from tenant context, never from the request.
 */
export class NotificationService {
    constructor(private readonly db: DatabaseClient = prisma) {}

    async listForUser(userId: string, orgId: string, options: ListNotificationsOptions) {
        const skip = (options.page - 1) * options.limit;
        const where = {
            userId,
            orgId,
            deletedAt: null,
            ...(options.unreadOnly && { readAt: null }),
        };

        const [notifications, total, unread] = await Promise.all([
            this.db.notification.findMany({
                where,
                select: NOTIFICATION_SELECT,
                orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                skip,
                take: options.limit,
            }),
            this.db.notification.count({ where }),
            this.db.notification.count({
                where: { userId, orgId, deletedAt: null, readAt: null },
            }),
        ]);

        return {
            notifications,
            total,
            unread,
            page: options.page,
            totalPages: Math.ceil(total / options.limit),
        };
    }

    async markRead(userId: string, orgId: string, notificationId: string) {
        return this.db.$transaction(async (tx) => {
            const notification = await tx.notification.findFirst({
                where: { id: notificationId, userId, orgId, deletedAt: null },
                select: { id: true, readAt: true },
            });
            if (!notification) {
                throw new AppError('NOTIFICATION_NOT_FOUND', 'Notification not found.', 404);
            }
            if (notification.readAt) {
                return { id: notification.id, readAt: notification.readAt, changed: false };
            }

            const readAt = new Date();
            // Guarded updateMany — same optimistic pattern as announcement
            // acknowledgement: only a still-unread row can transition.
            const transition = await tx.notification.updateMany({
                where: { id: notificationId, userId, orgId, deletedAt: null, readAt: null },
                data: { readAt },
            });
            if (transition.count === 1) {
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'Notification',
                        entityId: notificationId,
                        changes: { read: true },
                        userId,
                        orgId,
                        targetId: userId,
                    },
                }).catch((error) => {
                    // Read-receipt must never fail the request; audit loss is logged.
                    logger.error('notification.read_audit_failed', error, { notificationId });
                });
                return { id: notification.id, readAt, changed: true };
            }

            const current = await tx.notification.findFirst({
                where: { id: notificationId, userId, orgId, deletedAt: null },
                select: { readAt: true },
            });
            if (!current?.readAt) {
                throw new AppError('NOTIFICATION_READ_CONFLICT', 'Notification could not be marked read.', 409);
            }
            return { id: notification.id, readAt: current.readAt, changed: false };
        });
    }

    async markAllRead(userId: string, orgId: string) {
        const readAt = new Date();
        const result = await this.db.notification.updateMany({
            where: { userId, orgId, deletedAt: null, readAt: null },
            data: { readAt },
        });
        if (result.count > 0) {
            await this.db.auditLog.create({
                data: {
                    action: 'UPDATE',
                    entityType: 'Notification',
                    // AuditLog.entityId is a not-null uuid — the batch has no
                    // single entity, so it is anchored to the actor.
                    entityId: userId,
                    changes: { readAll: true, count: result.count },
                    userId,
                    orgId,
                    targetId: userId,
                },
            }).catch((error) => {
                logger.error('notification.readall_audit_failed', error, { userId });
            });
        }
        return { updated: result.count, readAt };
    }
}

export const notificationService = new NotificationService();
