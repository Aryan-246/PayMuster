import { prisma } from './prisma.js';
import { eventBus, Events } from './events.js';
import { logger } from './logger.js';
import { pushNotificationService } from '../services/push-notification.service.js';

export function setupSystemListeners() {
  // 1. Notification Listener
  eventBus.on('Notification', async (payload: { orgId: string, userId?: string, title: string, body: string, type: string, deepLink?: string }) => {
    try {
      const validOrgId = payload.orgId && payload.orgId !== 'SYSTEM' && /^[0-9a-fA-F-]{36}$/.test(payload.orgId) ? payload.orgId : null;
      const notification = await prisma.notification.create({
        data: {
          orgId: validOrgId,
          userId: payload.userId,
          title: payload.title,
          body: payload.body,
          type: payload.type,
          deepLink: payload.deepLink,
        },
        select: { id: true, orgId: true, userId: true, title: true, body: true, type: true, deepLink: true },
      });

      logger.info('notification.created', { notificationId: notification.id, orgId: notification.orgId, type: notification.type });
      if (notification.orgId) {
        await pushNotificationService.dispatch(notification).catch((error) => {
          logger.error('push.notification_dispatch_failed', error, {
            notificationId: notification.id,
            orgId: notification.orgId,
          });
        });
      }
    } catch (error) {
      logger.error('notification.create_failed', error, { orgId: payload.orgId, type: payload.type });
    }
  });

  // Example mappings from specific Events to Notifications
  eventBus.on(Events.WORKER_JOINED_SITE, async (payload: { orgId: string, siteId: string, userId: string, assignedBy: string }) => {
    eventBus.emitEvent('Notification', {
      orgId: payload.orgId,
      userId: payload.userId,
      title: 'Added to Site',
      body: 'You have been added to a new site.',
      type: 'SITE_ASSIGNMENT'
    });
  });
}
