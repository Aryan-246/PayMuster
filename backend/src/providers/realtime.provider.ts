import { createRequire } from 'node:module';
import { config } from '../lib/config.js';
import { prisma } from '../lib/prisma.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth, RealtimeChannelRequest, RealtimeProvider } from './contracts.js';

const require = createRequire(import.meta.url);

const STREAM_TOKEN_TTL_SECONDS = 60 * 60; // 1 hour

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
            readiness: 'READY',
            enabled: true,
            checkedAt: new Date().toISOString(),
            detail: 'Durable notifications plus SSE, polling, and in-process EventBus.',
        };
    }
}

export class StreamProvider implements RealtimeProvider {
    readonly name = 'stream';
    private sdk: any | null = null;
    private sdkError: string | null = null;

    /**
     * Real channel authorization (blueprint C5): the same tenant + member checks
     * as ExistingRealtimeProvider — the requesting user must belong to the org,
     * be among the channel members, and (when site-scoped) the site must belong
     * to the org. SUPER_ADMIN is excluded from tenant channels (platform scope).
     */
    async authorize(request: RealtimeChannelRequest): Promise<boolean> {
        if (!config.streamEnabled) return false;
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

    private getServerClient(): any | null {
        if (this.sdk) return this.sdk;
        if (this.sdkError) return null;
        if (!config.streamAppId || !config.streamApiKey || !config.streamApiSecret) {
            this.sdkError = 'Stream credentials are incomplete.';
            return null;
        }
        try {
            // stream-chat is installed; the server SDK mints JWTs signed with the
            // Stream API secret — the secret never leaves the server.
            const { StreamChat } = require('stream-chat');
            this.sdk = StreamChat.getInstance(config.streamApiKey, config.streamApiSecret);
            return this.sdk;
        } catch (err: any) {
            this.sdkError = `stream-chat SDK unavailable: ${err.message}`;
            logger.error('stream.sdk_init_failed', err);
            return null;
        }
    }

    /**
     * Server-side Stream token mint (blueprint §K): creates the user token for a
     * channel member after authorize() has validated tenant scope. Returns null
     * when Stream is not usable — callers must surface an honest unavailable
     * state, never a fabricated token.
     */
    async createToken(userId: string, expiresAt?: Date): Promise<string | null> {
        const client = this.getServerClient();
        if (!client) return null;
        try {
            const expiry = Math.floor((expiresAt?.getTime() ?? Date.now() + STREAM_TOKEN_TTL_SECONDS * 1000) / 1000);
            return client.createToken(userId, expiry);
        } catch (err: any) {
            logger.error('stream.token_mint_failed', err, { userId });
            return null;
        }
    }

    async health(): Promise<ProviderHealth> {
        const configured = Boolean(config.streamAppId && config.streamApiKey && config.streamApiSecret);
        const enabled = config.streamEnabled;
        const client = enabled && configured ? this.getServerClient() : null;
        if (enabled && configured && !client) {
            return {
                provider: this.name,
                kind: 'REALTIME',
                enabled,
                status: 'INVALID_CONFIGURATION',
                readiness: 'ENVIRONMENT_BLOCKED',
                fallback: 'sse-poll-eventbus',
                checkedAt: new Date().toISOString(),
                detail: this.sdkError || 'Stream SDK could not be initialized.',
            };
        }
        return {
            provider: this.name,
            kind: 'REALTIME',
            enabled,
            status: !enabled ? 'DISABLED' : configured ? 'CONNECTED' : 'UNAVAILABLE',
            readiness: !enabled ? 'DISABLED' : configured ? 'READY' : 'MISSING_CONFIGURATION',
            fallback: 'sse-poll-eventbus',
            checkedAt: new Date().toISOString(),
            detail: !enabled
                ? 'SSE, polling, and the in-process event bus remain authoritative.'
                : configured
                    ? 'Stream credentials are present; server-side session minting is active.'
                    : 'Stream is enabled but required server configuration is incomplete.',
        };
    }
}

export const existingRealtimeProvider = new ExistingRealtimeProvider();
export const streamProvider = new StreamProvider();
