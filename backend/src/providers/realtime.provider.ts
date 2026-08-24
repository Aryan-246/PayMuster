import { config } from '../lib/config.js';
import { prisma } from '../lib/prisma.js';
import type { ProviderHealth, RealtimeChannelRequest, RealtimeProvider } from './contracts.js';

export class ExistingRealtimeProvider implements RealtimeProvider {
    readonly name = 'sse-poll-eventbus';

    async authorize(request: RealtimeChannelRequest): Promise<boolean> {
        if (!request.orgId || request.context.orgId !== request.orgId) return false;
        if (request.context.role === 'SUPER_ADMIN') return false;
        if (!request.memberIds.includes(request.context.userId)) return false;
        if (request.siteId) {
            const site = await prisma.site.findFirst({
                where: { id: request.siteId, orgId: request.orgId, deletedAt: null },
                select: { id: true },
            });
            if (!site) return false;
        }
        const members = await prisma.user.count({
            where: {
                id: { in: [...request.memberIds] },
                orgId: request.orgId,
                deletedAt: null,
                isActive: true,
                isDisabled: false,
            },
        });
        return members === new Set(request.memberIds).size;
    }

    async health(): Promise<ProviderHealth> {
        return {
            provider: this.name,
            kind: 'REALTIME',
            status: 'CONNECTED',
            enabled: true,
            checkedAt: new Date().toISOString(),
            detail: 'Durable notifications plus SSE, polling, and in-process EventBus.',
        };
    }
}

export class StreamProvider implements RealtimeProvider {
    readonly name = 'stream';

    async authorize(_request: RealtimeChannelRequest): Promise<boolean> {
        return false;
    }

    async health(): Promise<ProviderHealth> {
        const configured = Boolean(config.streamAppId && config.streamApiKey && config.streamApiSecret);
        const enabled = config.streamEnabled;
        return {
            provider: this.name,
            kind: 'REALTIME',
            enabled,
            status: !enabled ? 'DISABLED' : 'UNAVAILABLE',
            readiness: !enabled ? 'DISABLED' : 'ENVIRONMENT_BLOCKED',
            fallback: 'sse-poll-eventbus',
            checkedAt: new Date().toISOString(),
            detail: !enabled
                ? 'SSE, polling, and the in-process event bus remain authoritative.'
                : configured
                    ? 'Stream credentials are present, but the adapter is blocked until entitlement and delivery policy are verified.'
                    : 'Stream is enabled but remains blocked; required server configuration is incomplete.',
        };
    }
}

export const existingRealtimeProvider = new ExistingRealtimeProvider();
export const streamProvider = new StreamProvider();
