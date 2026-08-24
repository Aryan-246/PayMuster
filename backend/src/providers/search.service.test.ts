import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/app-error.js';
import type { ProviderHealth, SearchProvider, SearchRequest, SearchResult } from './contracts.js';
import { SearchService } from './search.service.js';

const request: SearchRequest = {
    query: 'worker',
    page: 1,
    limit: 25,
    filters: {},
    context: {
        userId: 'user-1',
        role: 'STAFF',
        orgId: 'org-1',
        permissions: ['view_staff'],
    },
};

const health = (provider: string): ProviderHealth => ({
    provider,
    kind: 'SEARCH',
    status: 'CONNECTED',
    enabled: true,
    checkedAt: new Date().toISOString(),
});

const result = (provider: string, fallbackUsed: boolean): SearchResult => ({
    hits: [],
    total: 0,
    page: 1,
    totalPages: 0,
    provider,
    fallbackUsed,
});

test('search service uses the fallback when the optional provider is disabled', async () => {
    const calls: string[] = [];
    const primary: SearchProvider = {
        name: 'algolia',
        search: async () => { calls.push('primary'); return result('algolia', false); },
        health: async () => health('algolia'),
    };
    const fallback: SearchProvider = {
        name: 'database',
        search: async () => { calls.push('fallback'); return result('database', true); },
        health: async () => health('database'),
    };
    const service = new SearchService(fallback, primary, false);
    const response = await service.search(request);
    assert.equal(response.provider, 'database');
    assert.deepEqual(calls, ['fallback']);
});

test('search service falls back when the optional provider is unavailable', async () => {
    const calls: string[] = [];
    const primary: SearchProvider = {
        name: 'algolia',
        search: async () => { calls.push('primary'); throw new AppError('SEARCH_UNAVAILABLE', 'Unavailable', 503); },
        health: async () => health('algolia'),
    };
    const fallback: SearchProvider = {
        name: 'database',
        search: async () => { calls.push('fallback'); return result('database', true); },
        health: async () => health('database'),
    };
    const service = new SearchService(fallback, primary, true);
    const response = await service.search(request);
    assert.equal(response.provider, 'database');
    assert.deepEqual(calls, ['primary', 'fallback']);
});

test('search service propagates unexpected primary errors instead of hiding corruption', async () => {
    const primary: SearchProvider = {
        name: 'algolia',
        search: async () => { throw new AppError('SEARCH_DATA_CORRUPTION', 'Unexpected', 500); },
        health: async () => health('algolia'),
    };
    const fallback: SearchProvider = {
        name: 'database',
        search: async () => result('database', true),
        health: async () => health('database'),
    };
    await assert.rejects(new SearchService(fallback, primary, true).search(request), /Unexpected/);
});
