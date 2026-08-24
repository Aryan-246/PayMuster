import { AppError } from '../lib/app-error.js';
import { config } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import type { SearchProvider, SearchRequest, SearchResult, ProviderHealth } from './contracts.js';
import { databaseSearchProvider } from './database-search.provider.js';
import { algoliaProvider } from './algolia.provider.js';

/**
 * Algolia-backed search provider — uses the real Algolia SDK via algolia.provider.ts.
 * Falls back to database search when Algolia is unavailable or returns no results.
 */
export class AlgoliaSearchProvider implements SearchProvider {
    readonly name = 'algolia';

    async search(request: SearchRequest): Promise<SearchResult> {
        if (!config.algoliaEnabled) {
            throw new AppError(
                'SEARCH_UNAVAILABLE',
                'Algolia search is not enabled; falling back to database search.',
                503,
            );
        }

        try {
            return await algoliaProvider.search(request);
        } catch (error) {
            if (error instanceof AppError) throw error;
            throw new AppError(
                'SEARCH_UNAVAILABLE',
                `Algolia search failed: ${error instanceof Error ? error.message : String(error)}`,
                503,
            );
        }
    }

    async health(): Promise<ProviderHealth> {
        return algoliaProvider.health();
    }
}

export class SearchService {
    constructor(
        private readonly fallback: SearchProvider = databaseSearchProvider,
        private readonly primary: SearchProvider = new AlgoliaSearchProvider(),
        private readonly primaryEnabled: boolean = config.algoliaEnabled,
    ) { }

    async search(request: SearchRequest): Promise<SearchResult> {
        if (this.primaryEnabled) {
            try {
                return await this.primary.search(request);
            } catch (error) {
                if (!(error instanceof AppError) || error.code !== 'SEARCH_UNAVAILABLE') {
                    throw error;
                }
                logger.warn('search.algolia_fallback', { reason: error.message, query: request.query });
            }
        }
        return this.fallback.search(request);
    }

    async health(): Promise<ProviderHealth[]> {
        return Promise.all([this.primary.health(), this.fallback.health()]);
    }
}

export const searchService = new SearchService();
