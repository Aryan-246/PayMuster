import { randomUUID } from 'node:crypto';

import { logger } from './logger.js';

export const PlatformEventName = {
    USER_CREATED: 'USER_CREATED',
    USER_UPDATED: 'USER_UPDATED',
    USER_SUSPENDED: 'USER_SUSPENDED',
    USER_RESTORED: 'USER_RESTORED',
    USER_DELETED: 'USER_DELETED',
    OWNER_REQUEST_CREATED: 'OWNER_REQUEST_CREATED',
    OWNER_REQUEST_APPROVED: 'OWNER_REQUEST_APPROVED',
    OWNER_REQUEST_REJECTED: 'OWNER_REQUEST_REJECTED',
    DOCUMENT_UPLOADED: 'DOCUMENT_UPLOADED',
    DOCUMENT_REVIEW_STARTED: 'DOCUMENT_REVIEW_STARTED',
    DOCUMENT_VERIFIED: 'DOCUMENT_VERIFIED',
    DOCUMENT_REJECTED: 'DOCUMENT_REJECTED',
    DOCUMENT_RESUBMITTED: 'DOCUMENT_RESUBMITTED',
    ANNOUNCEMENT_CREATED: 'ANNOUNCEMENT_CREATED',
    ANNOUNCEMENT_PUBLISHED: 'ANNOUNCEMENT_PUBLISHED',
    ANNOUNCEMENT_ACKNOWLEDGED: 'ANNOUNCEMENT_ACKNOWLEDGED',
    MAINTENANCE_ENABLED: 'MAINTENANCE_ENABLED',
    MAINTENANCE_DISABLED: 'MAINTENANCE_DISABLED',
    SESSION_REVOKED: 'SESSION_REVOKED',
    ATTENDANCE_CREATED: 'ATTENDANCE_CREATED',
    ATTENDANCE_UPDATED: 'ATTENDANCE_UPDATED',
    PAYROLL_CREATED: 'PAYROLL_CREATED',
    PAYROLL_UPDATED: 'PAYROLL_UPDATED',
    PAYROLL_APPROVED: 'PAYROLL_APPROVED',
    PAYROLL_PAID: 'PAYROLL_PAID',
    SITE_CREATED: 'SITE_CREATED',
    SITE_UPDATED: 'SITE_UPDATED',
    SITE_VERIFIED: 'SITE_VERIFIED',
    COMPANY_CREATED: 'COMPANY_CREATED',
    COMPANY_UPDATED: 'COMPANY_UPDATED',
    AI_ANALYSIS_COMPLETED: 'AI_ANALYSIS_COMPLETED',
} as const;

export type PlatformEventName = typeof PlatformEventName[keyof typeof PlatformEventName];

export interface PlatformEvent<TPayload extends Record<string, unknown> = Record<string, unknown>> {
    id: string;
    name: PlatformEventName;
    occurredAt: string;
    actorId?: string;
    orgId?: string | null;
    targetId?: string;
    payload: TPayload;
}

export function createPlatformEvent<TPayload extends Record<string, unknown>>(
    name: PlatformEventName,
    payload: TPayload,
    context: Pick<PlatformEvent, 'actorId' | 'orgId' | 'targetId'> = {},
): PlatformEvent<TPayload> {
    return {
        id: randomUUID(),
        name,
        occurredAt: new Date().toISOString(),
        ...context,
        payload,
    };
}

export function logPlatformEvent(event: PlatformEvent): void {
    logger.info('platform.event', {
        eventId: event.id,
        eventName: event.name,
        actorId: event.actorId,
        orgId: event.orgId,
        targetId: event.targetId,
    });
}
