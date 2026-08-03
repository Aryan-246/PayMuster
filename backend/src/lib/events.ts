import EventEmitter from 'events';
import { logger } from './logger.js';

class EventBus extends EventEmitter {
  emitEvent(eventName: string, payload: any) {
    logger.info(`[EventBus] Emitting ${eventName}`, payload);
    this.emit(eventName, payload);
  }
}

export const eventBus = new EventBus();

// Strongly typed event names
export const Events = {
  SITE_CREATED: 'SiteCreated',
  SITE_UPDATED: 'SiteUpdated',
  SITE_STATUS_CHANGED: 'SiteStatusChanged',
  WORKER_JOINED_SITE: 'WorkerJoinedSite',
  WORKER_REMOVED_SITE: 'WorkerRemovedSite',
  COMPANY_CREATED: 'CompanyCreated',
  COMPANY_SUSPENDED: 'CompanySuspended',
  USER_DELETED: 'UserDeleted',
} as const;

// Example Handlers attachment
eventBus.on(Events.SITE_STATUS_CHANGED, (payload) => {
  // E.g. { siteId, oldStatus, newStatus, userId }
  logger.info(`Handling ${Events.SITE_STATUS_CHANGED}`, payload);
  // Future: Create AuditLog entry, push to websockets, etc.
});
