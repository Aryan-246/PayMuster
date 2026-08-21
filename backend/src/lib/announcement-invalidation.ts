import { EventEmitter } from 'node:events';

export interface AnnouncementInvalidationEvent {
    reason: 'DISPATCHED' | 'ACKNOWLEDGED';
    occurredAt: string;
}

type AnnouncementListener = (event: AnnouncementInvalidationEvent) => void;

class AnnouncementInvalidationBroker {
    private readonly emitter = new EventEmitter();

    constructor() {
        this.emitter.setMaxListeners(0);
    }

    subscribe(userId: string, listener: AnnouncementListener): () => void {
        this.emitter.on(userId, listener);
        return () => this.emitter.off(userId, listener);
    }

    publish(userIds: Iterable<string>, event: AnnouncementInvalidationEvent): void {
        for (const userId of new Set(userIds)) {
            this.emitter.emit(userId, event);
        }
    }
}

export const announcementInvalidationBroker = new AnnouncementInvalidationBroker();
