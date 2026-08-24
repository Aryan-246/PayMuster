import { createRequire } from 'node:module';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth, SearchProvider, SearchRequest, SearchResult, SearchHit } from './contracts.js';
import { databaseSearchProvider } from './database-search.provider.js';

const require = createRequire(import.meta.url);

function now(): string {
    return new Date().toISOString();
}

interface AlgoliaRecord {
    objectID: string;
    [key: string]: unknown;
}

interface AlgoliaSearchResult {
    hits: AlgoliaRecord[];
    nbHits: number;
    query: string;
    processingTimeMS: number;
}

/**
 * Algolia search provider — indexes PayMuster entities (users, companies, sites)
 * with tenant-safe filtering via orgId. Falls back to database-search when unavailable.
 */
export class AlgoliaProvider implements SearchProvider {
    readonly name = 'algolia';
    private client: any = null;
    private initError: string | null = null;

    private getClient() {
        if (this.client) return this.client;
        if (this.initError) return null;

        if (!config.algoliaEnabled || !config.algoliaApplicationId || !config.algoliaAdminApiKey) {
            this.initError = 'Algolia is not enabled or credentials are missing.';
            return null;
        }

        try {
            const { algoliasearch } = require('algoliasearch');
            this.client = algoliasearch(config.algoliaApplicationId, config.algoliaAdminApiKey);
            return this.client;
        } catch (err: any) {
            this.initError = `Failed to initialize Algolia client: ${err.message}`;
            logger.error('algolia.init_failed', err);
            return null;
        }
    }

    private indexName(entity: string): string {
        return `${config.algoliaIndexPrefix}_${entity}`;
    }

    async health(): Promise<ProviderHealth> {
        if (!config.algoliaEnabled) {
            return {
                provider: 'algolia',
                kind: 'SEARCH',
                status: 'DISABLED',
                readiness: 'DISABLED',
                enabled: false,
                fallback: 'database',
                checkedAt: now(),
                detail: 'Algolia search is disabled.',
            };
        }

        const client = this.getClient();
        if (!client) {
            return {
                provider: 'algolia',
                kind: 'SEARCH',
                status: 'INVALID_CONFIGURATION',
                readiness: 'MISSING_CONFIGURATION',
                enabled: true,
                fallback: 'database',
                checkedAt: now(),
                detail: this.initError || 'Algolia credentials incomplete.',
            };
        }

        try {
            await client.listIndices();
            return {
                provider: 'algolia',
                kind: 'SEARCH',
                status: 'CONNECTED',
                readiness: 'READY',
                enabled: true,
                fallback: 'database',
                checkedAt: now(),
                detail: 'Algolia is reachable and responding.',
            };
        } catch (err: any) {
            const isAuthError = err.status === 403 || err.status === 401 || err.message?.includes('Invalid');
            return {
                provider: 'algolia',
                kind: 'SEARCH',
                status: 'UNAVAILABLE',
                readiness: isAuthError ? 'INVALID_CONFIGURATION' : 'ENVIRONMENT_BLOCKED',
                enabled: true,
                fallback: 'database',
                checkedAt: now(),
                detail: isAuthError
                    ? 'Algolia credentials rejected: auth verification failed (INVALID_CREDENTIAL).'
                    : `Algolia health check failed: ${err.message || String(err)}`,
            };
        }
    }

    async search(request: SearchRequest): Promise<SearchResult> {
        const client = this.getClient();
        if (!client) {
            throw new Error('Algolia client not available');
        }

        const entityType = request.filters?.entityTypes?.[0] || 'USER';
        const orgFilter = request.context.orgId ? `_orgId:${request.context.orgId}` : '';

        try {
            const { results } = await client.search({
                requests: [{
                    indexName: this.indexName(entityType.toLowerCase()),
                    query: request.query,
                    hitsPerPage: request.limit || 20,
                    page: (request.page || 1) - 1,
                    filters: orgFilter || undefined,
                }],
            });

            const firstResult: AlgoliaSearchResult = results?.[0] ?? { hits: [], nbHits: 0, query: request.query, processingTimeMS: 0 };
            const hits: SearchHit[] = firstResult.hits.map((hit) => ({
                id: hit.objectID,
                entityType,
                title: String(hit.title || hit.name || hit.firstName || hit.objectID),
                subtitle: hit.subtitle ? String(hit.subtitle) : undefined,
                status: hit.status ? String(hit.status) : undefined,
                orgId: request.context.orgId,
                metadata: {},
            }));

            return {
                hits,
                total: firstResult.nbHits,
                page: request.page || 1,
                totalPages: Math.ceil(firstResult.nbHits / (request.limit || 20)) || 1,
                provider: this.name,
                fallbackUsed: false,
            };
        } catch (err: any) {
            logger.error('algolia.search_failed', err, { query: request.query, orgId: request.context.orgId });
            throw err;
        }
    }

    async indexRecord(entity: string, record: AlgoliaRecord, orgId: string): Promise<{ success: boolean; error?: string }> {
        const client = this.getClient();
        if (!client) {
            logger.warn('algolia.index_skipped', { entity, reason: 'client not available' });
            return { success: false, error: 'Algolia client not available' };
        }

        try {
            const enriched = { ...record, _orgId: orgId, _indexedAt: now() };
            await client.saveObject({ indexName: this.indexName(entity), body: enriched });
            logger.info('algolia.record_indexed', { entity, objectID: record.objectID, orgId });
            return { success: true };
        } catch (err: any) {
            logger.error('algolia.index_failed', err, { entity, objectID: record.objectID });
            return { success: false, error: err.message };
        }
    }

    async deleteRecord(entity: string, objectID: string): Promise<{ success: boolean; error?: string }> {
        const client = this.getClient();
        if (!client) {
            return { success: false, error: 'Algolia client not available' };
        }

        try {
            await client.deleteObject({ indexName: this.indexName(entity), objectID });
            logger.info('algolia.record_deleted', { entity, objectID });
            return { success: true };
        } catch (err: any) {
            logger.error('algolia.delete_failed', err, { entity, objectID });
            return { success: false, error: err.message };
        }
    }

    async testConnection(): Promise<{ reachable: boolean; authenticated: boolean; error?: string }> {
        const client = this.getClient();
        if (!client) {
            return { reachable: false, authenticated: false, error: this.initError || 'Client not available' };
        }

        try {
            await client.listIndices();
            return { reachable: true, authenticated: true };
        } catch (err: any) {
            const isAuthError = err.status === 403 || err.status === 401;
            return {
                reachable: !isAuthError,
                authenticated: false,
                error: err.message,
            };
        }
    }
}

export const algoliaProvider = new AlgoliaProvider();
