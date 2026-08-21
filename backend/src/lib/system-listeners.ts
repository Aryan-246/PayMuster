import { prisma } from './prisma.js';
import { eventBus, Events } from './events.js';
import { logger } from './logger.js';
import { AuditAction } from '../../generated/prisma/index.js';

export function setupSystemListeners() {
  // 1. Notification Listener
  eventBus.on('Notification', async (payload: { orgId: string, userId?: string, title: string, body: string, type: string, deepLink?: string }) => {
    try {
      const validOrgId = payload.orgId && payload.orgId !== 'SYSTEM' && /^[0-9a-fA-F-]{36}$/.test(payload.orgId) ? payload.orgId : null;
      await prisma.notification.create({
        data: {
          orgId: validOrgId as any,
          userId: payload.userId, // Null means broadcast to org
          title: payload.title,
          body: payload.body,
          type: payload.type,
          deepLink: payload.deepLink,
        } as any
      });


      logger.info(`[Notification] Created: ${payload.title}`);
    } catch (error) {
      logger.error('[Notification] Failed to create notification:', error);
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
