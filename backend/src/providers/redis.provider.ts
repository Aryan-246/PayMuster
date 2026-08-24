import { createRequire } from 'node:module';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth } from './contracts.js';

const require = createRequire(import.meta.url);

function now(): string {
    return new Date().toISOString();
}

/**
 * Redis/Upstash provider — caching, rate-limiting, and session storage.
 * Uses @upstash/redis REST client for serverless-friendly connections.
 * Falls back to application-level caching / PostgreSQL when unavailable.
 */
export class RedisProvider {
    readonly name = 'redis';
    private client: any = null;
    private initError: string | null = null;

    private getClient() {
        if (this.client) return this.client;
        if (this.initError) return null;

        if (!config.redisEnabled) {
            this.initError = 'Redis is not enabled.';
            return null;
        }

        // Prefer Upstash REST client (already in package.json)
        if (config.upstashRedisRestUrl && config.upstashRedisRestToken) {
            try {
                const { Redis } = require('@upstash/redis');
                this.client = new Redis({
                    url: config.upstashRedisRestUrl,
                    token: config.upstashRedisRestToken,
                });
                return this.client;
            } catch (err: any) {
                this.initError = `Failed to initialize Upstash Redis: ${err.message}`;
                logger.error('redis.init_failed', err);
                return null;
            }
        }

        this.initError = 'No Redis URL or Upstash REST credentials configured.';
        return null;
    }

    async health(): Promise<ProviderHealth> {
        if (!config.redisEnabled) {
            return {
                provider: 'redis',
                kind: 'REALTIME',
                status: 'DISABLED',
                readiness: 'DISABLED',
                enabled: false,
                fallback: 'postgres-event-boundary',
                checkedAt: now(),
                detail: 'Redis cache is disabled.',
            };
        }

        const client = this.getClient();
        if (!client) {
            return {
                provider: 'redis',
                kind: 'REALTIME',
                status: 'INVALID_CONFIGURATION',
                readiness: 'MISSING_CONFIGURATION',
                enabled: true,
                fallback: 'postgres-event-boundary',
                checkedAt: now(),
                detail: this.initError || 'Redis client not available.',
            };
        }

        try {
            const pong = await client.ping();
            return {
                provider: 'redis',
                kind: 'REALTIME',
                status: pong === 'PONG' ? 'CONNECTED' : 'UNAVAILABLE',
                readiness: pong === 'PONG' ? 'READY' : 'ENVIRONMENT_BLOCKED',
                enabled: true,
                fallback: 'postgres-event-boundary',
                checkedAt: now(),
                detail: pong === 'PONG' ? 'Redis is reachable and responding.' : `Unexpected ping response: ${pong}`,
            };
        } catch (err: any) {
            const isAuthError = err.message?.includes('WRONGPASS') || err.message?.includes('NOAUTH') || err.message?.includes('Unauthorized');
            return {
                provider: 'redis',
                kind: 'REALTIME',
                status: 'UNAVAILABLE',
                readiness: isAuthError ? 'INVALID_CONFIGURATION' : 'ENVIRONMENT_BLOCKED',
                enabled: true,
                fallback: 'postgres-event-boundary',
                checkedAt: now(),
                detail: isAuthError
                    ? 'Redis credentials rejected: authentication check failed (INVALID_CREDENTIAL).'
                    : `Redis health check failed: ${err.message}`,
            };
        }
    }

    async get(key: string): Promise<string | null> {
        const client = this.getClient();
        if (!client) return null;

        try {
            return await client.get(key);
        } catch (err: any) {
            logger.error('redis.get_failed', err, { key });
            return null;
        }
    }

    async set(key: string, value: string, ttlSeconds?: number): Promise<boolean> {
        const client = this.getClient();
        if (!client) return false;

        try {
            if (ttlSeconds) {
                await client.set(key, value, { ex: ttlSeconds });
            } else {
                await client.set(key, value);
            }
            return true;
        } catch (err: any) {
            logger.error('redis.set_failed', err, { key });
            return false;
        }
    }

    async del(key: string): Promise<boolean> {
        const client = this.getClient();
        if (!client) return false;

        try {
            await client.del(key);
            return true;
        } catch (err: any) {
            logger.error('redis.del_failed', err, { key });
            return false;
        }
    }

    async incr(key: string): Promise<number | null> {
        const client = this.getClient();
        if (!client) return null;

        try {
            return await client.incr(key);
        } catch (err: any) {
            logger.error('redis.incr_failed', err, { key });
            return null;
        }
    }

    async ttl(key: string): Promise<number | null> {
        const client = this.getClient();
        if (!client) return null;

        try {
            return await client.ttl(key);
        } catch (err: any) {
            logger.error('redis.ttl_failed', err, { key });
            return null;
        }
    }

    async testConnection(): Promise<{ reachable: boolean; authenticated: boolean; pingResult?: string; error?: string }> {
        const client = this.getClient();
        if (!client) {
            return { reachable: false, authenticated: false, error: this.initError || 'Client not available' };
        }

        try {
            const pong = await client.ping();
            return { reachable: true, authenticated: true, pingResult: pong };
        } catch (err: any) {
            const isAuthError = err.message?.includes('WRONGPASS') || err.message?.includes('NOAUTH') || err.message?.includes('Unauthorized');
            return {
                reachable: !isAuthError,
                authenticated: false,
                error: err.message,
            };
        }
    }
}

export const redisProvider = new RedisProvider();
