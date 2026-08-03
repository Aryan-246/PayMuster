import { prisma } from './prisma.js';
import { eventBus } from './events.js';

export function setupAuditListener() {
  eventBus.on('AuditLog', async (payload: {
    orgId: string;
    userId?: string;
    action: any;
    entityType: string;
    entityId: string;
    targetId?: string;
    changes: any;
  }) => {
    try {
      await prisma.auditLog.create({
        data: {
          orgId: payload.orgId,
          userId: payload.userId,
          action: payload.action,
          entityType: payload.entityType,
          entityId: payload.entityId,
          targetId: payload.targetId,
          changes: payload.changes,
        }
      });
    } catch (err) {
      console.error('[AuditLog] Failed to insert log', err);
    }
  });
}
