import { AppError } from '../lib/app-error.js';
import { logger } from '../lib/logger.js';
import { prisma } from '../lib/prisma.js';
import { firebaseFcmProvider } from '../providers/firebase-fcm.provider.js';
import type { PushPlatform } from '../../generated/prisma/index.js';

const MAX_DELIVERY_ATTEMPTS = 3;

export interface RegisterDeviceInput {
    orgId: string | null;
    userId: string;
    token: string;
    platform: PushPlatform;
    appVersion?: string;
    deviceId?: string;
}

export interface NotificationPayload {
    id: string;
    orgId: string | null;
    userId: string | null;
    title: string;
    body: string;
    type: string;
    deepLink: string | null;
}

type DeviceTokenRecord = {
    id: string;
    orgId: string;
    userId: string;
    token: string;
};

function tokenFingerprint(token: string): string {
    return `${token.slice(0, 4)}...${token.slice(-4)}`;
}

function deliveryData(notification: NotificationPayload): Record<string, string> {
    const data: Record<string, string> = {
        notification_id: notification.id,
        notification_type: notification.type,
    };
    if (notification.deepLink) data.deep_link = notification.deepLink;
    return data;
}

export class PushNotificationService {
    async registerDevice(input: RegisterDeviceInput) {
        if (!input.orgId) {
            throw new AppError('PUSH_ORGANIZATION_REQUIRED', 'A device can only be registered for an organization account.', 400);
        }
        if (input.token.trim().length < 20 || input.token.trim().length > 4096) {
            throw new AppError('PUSH_TOKEN_INVALID', 'The push token is invalid.', 400);
        }

        const user = await prisma.user.findFirst({
            where: { id: input.userId, orgId: input.orgId, isActive: true, isDisabled: false, deletedAt: null },
            select: { id: true, orgId: true },
        });
        if (!user || !user.orgId) {
            throw new AppError('PUSH_ACCOUNT_NOT_FOUND', 'The account is not available for push registration.', 404);
        }

        const token = input.token.trim();
        const existingToken = await prisma.deviceToken.findUnique({
            where: { token },
            select: { id: true, orgId: true, userId: true },
        });
        if (existingToken && (existingToken.orgId !== input.orgId || existingToken.userId !== input.userId)) {
            await prisma.deviceToken.update({
                where: { id: existingToken.id },
                data: {
                    orgId: input.orgId,
                    userId: input.userId,
                    platform: input.platform,
                    appVersion: input.appVersion,
                    deviceId: input.deviceId,
                    lastSeenAt: new Date(),
                    invalidatedAt: null,
                    invalidationReason: null,
                },
            });
            logger.info('push.device_reassigned', { orgId: input.orgId, userId: input.userId, tokenFingerprint: tokenFingerprint(token) });
            return { registered: true };
        }

        await prisma.deviceToken.upsert({
            where: { token },
            create: {
                orgId: input.orgId,
                userId: input.userId,
                token,
                platform: input.platform,
                appVersion: input.appVersion,
                deviceId: input.deviceId,
            },
            update: {
                orgId: input.orgId,
                userId: input.userId,
                platform: input.platform,
                appVersion: input.appVersion,
                deviceId: input.deviceId,
                lastSeenAt: new Date(),
                invalidatedAt: null,
                invalidationReason: null,
            },
        });
        return { registered: true };
    }

    async unregisterDevice(userId: string, orgId: string | null, token: string) {
        if (!orgId) throw new AppError('PUSH_ORGANIZATION_REQUIRED', 'An organization context is required.', 400);
        const result = await prisma.deviceToken.updateMany({
            where: { userId, orgId, token: token.trim(), invalidatedAt: null },
            data: { invalidatedAt: new Date(), invalidationReason: 'CLIENT_UNREGISTERED' },
        });
        return { unregistered: result.count > 0 };
    }

    async dispatch(notification: NotificationPayload): Promise<void> {
        if (!notification.orgId) return;

        const devices = await prisma.deviceToken.findMany({
            where: {
                orgId: notification.orgId,
                invalidatedAt: null,
                ...(notification.userId ? { userId: notification.userId } : {}),
            },
            select: { id: true, orgId: true, userId: true, token: true },
        });
        if (devices.length === 0) return;

        await prisma.notificationDelivery.createMany({
            data: devices.map((device) => ({
                orgId: notification.orgId as string,
                notificationId: notification.id,
                deviceTokenId: device.id,
            })),
            skipDuplicates: true,
        });

        const deliveries = await prisma.notificationDelivery.findMany({
            where: {
                orgId: notification.orgId,
                notificationId: notification.id,
                status: 'PENDING',
                attempts: { lt: MAX_DELIVERY_ATTEMPTS },
            },
            include: { deviceToken: { select: { id: true, token: true, invalidatedAt: true } } },
        });

        await Promise.all(deliveries.map((delivery) => this.deliverOne(notification, delivery)));
    }

    private async deliverOne(notification: NotificationPayload, delivery: {
        id: string;
        attempts: number;
        deviceToken: { id: string; token: string; invalidatedAt: Date | null };
    }): Promise<void> {
        if (delivery.deviceToken.invalidatedAt) return;

        const claim = await prisma.notificationDelivery.updateMany({
            where: {
                id: delivery.id,
                status: 'PENDING',
                attempts: delivery.attempts,
            },
            data: { attempts: { increment: 1 }, lastAttemptAt: new Date(), provider: firebaseFcmProvider.name },
        });
        if (claim.count !== 1) return;

        const result = await firebaseFcmProvider.send({
            eventId: delivery.id,
            token: delivery.deviceToken.token,
            title: notification.title,
            body: notification.body,
            data: deliveryData(notification),
        });

        if (result === 'SENT') {
            await prisma.notificationDelivery.update({
                where: { id: delivery.id },
                data: { status: 'SENT', deliveredAt: new Date(), errorCode: null },
            });
            return;
        }

        if (result === 'INVALID_TOKEN') {
            await prisma.$transaction([
                prisma.deviceToken.update({
                    where: { id: delivery.deviceToken.id },
                    data: { invalidatedAt: new Date(), invalidationReason: 'FCM_INVALID_TOKEN' },
                }),
                prisma.notificationDelivery.update({
                    where: { id: delivery.id },
                    data: { status: 'INVALID_TOKEN', errorCode: 'FCM_INVALID_TOKEN' },
                }),
            ]);
            return;
        }

        const exhausted = delivery.attempts + 1 >= MAX_DELIVERY_ATTEMPTS;
        await prisma.notificationDelivery.update({
            where: { id: delivery.id },
            data: { status: exhausted ? 'FAILED' : 'PENDING', errorCode: 'FCM_UNAVAILABLE' },
        });
        logger.warn('push.delivery_unavailable', {
            orgId: notification.orgId,
            notificationId: notification.id,
            deliveryId: delivery.id,
            attempts: delivery.attempts + 1,
            exhausted,
        });
    }
}

export const pushNotificationService = new PushNotificationService();
