import { AppError } from './app-error.js';
import { config } from './config.js';
import { logger } from './logger.js';

interface DocumentStorageConfig {
    supabaseUrl: string;
    serviceRoleKey: string;
    bucket: string;
    signedUrlTtlSeconds: number;
}

interface SignedUrlResponse {
    signedURL?: string;
    signedUrl?: string;
}

type FetchImplementation = typeof fetch;

function storageUnavailable(): AppError {
    return new AppError(
        'DOCUMENT_STORAGE_UNAVAILABLE',
        'Document storage is temporarily unavailable.',
        503,
    );
}

function assertStorageKey(storageKey: string): void {
    if (
        !storageKey ||
        storageKey.startsWith('/') ||
        storageKey.includes('..') ||
        storageKey.includes('\\') ||
        storageKey.includes('://') ||
        !/^[a-zA-Z0-9/_-]+\.[a-zA-Z0-9]+$/.test(storageKey)
    ) {
        throw new AppError(
            'DOCUMENT_STORAGE_KEY_INVALID',
            'This document does not have a valid private storage key.',
            409,
        );
    }
}

export class DocumentStorage {
    constructor(
        private readonly storageConfig: DocumentStorageConfig = {
            supabaseUrl: config.supabaseUrl,
            serviceRoleKey: config.supabaseServiceRoleKey,
            bucket: config.documentStorageBucket,
            signedUrlTtlSeconds: config.documentSignedUrlTtlSeconds,
        },
        private readonly fetchImplementation: FetchImplementation = fetch,
    ) { }

    async upload(storageKey: string, contentType: string, body: Buffer): Promise<void> {
        assertStorageKey(storageKey);
        const response = await this.request(
            this.objectUrl(storageKey),
            {
                method: 'POST',
                headers: {
                    'content-type': contentType,
                    'x-upsert': 'false',
                },
                body,
            },
        );

        if (!response.ok) {
            logger.error('document_storage.upload_failed', undefined, {
                status: response.status,
            });
            throw storageUnavailable();
        }
    }

    async createSignedViewUrl(storageKey: string): Promise<{ url: string; expiresInSeconds: number }> {
        assertStorageKey(storageKey);
        const response = await this.request(
            `${this.storageBaseUrl()}/object/sign/${this.encodedBucket()}/${this.encodedKey(storageKey)}`,
            {
                method: 'POST',
                headers: { 'content-type': 'application/json' },
                body: JSON.stringify({ expiresIn: this.storageConfig.signedUrlTtlSeconds }),
            },
        );

        if (!response.ok) {
            logger.error('document_storage.sign_failed', undefined, {
                status: response.status,
            });
            throw storageUnavailable();
        }

        let data: SignedUrlResponse;
        try {
            data = (await response.json()) as SignedUrlResponse;
        } catch {
            throw storageUnavailable();
        }

        const signedPath = data.signedURL ?? data.signedUrl;
        if (!signedPath) {
            throw storageUnavailable();
        }

        const url = signedPath.startsWith('http://') || signedPath.startsWith('https://')
            ? signedPath
            : `${this.storageBaseUrl()}${signedPath.startsWith('/') ? '' : '/'}${signedPath}`;

        return { url, expiresInSeconds: this.storageConfig.signedUrlTtlSeconds };
    }

    async remove(storageKey: string): Promise<void> {
        assertStorageKey(storageKey);
        const response = await this.request(this.objectUrl(storageKey), { method: 'DELETE' });
        if (!response.ok && response.status !== 404) {
            logger.error('document_storage.delete_failed', undefined, {
                status: response.status,
            });
            throw storageUnavailable();
        }
    }

    private async request(url: string, init: RequestInit): Promise<Response> {
        this.assertConfigured();
        try {
            return await this.fetchImplementation(url, {
                ...init,
                headers: {
                    apikey: this.storageConfig.serviceRoleKey,
                    authorization: `Bearer ${this.storageConfig.serviceRoleKey}`,
                    ...init.headers,
                },
                signal: AbortSignal.timeout(15_000),
            });
        } catch (error) {
            logger.error('document_storage.request_failed', error);
            throw storageUnavailable();
        }
    }

    private assertConfigured(): void {
        if (
            !this.storageConfig.supabaseUrl ||
            !this.storageConfig.serviceRoleKey ||
            !this.storageConfig.bucket
        ) {
            throw storageUnavailable();
        }
    }

    private storageBaseUrl(): string {
        return `${this.storageConfig.supabaseUrl}/storage/v1`;
    }

    private objectUrl(storageKey: string): string {
        return `${this.storageBaseUrl()}/object/${this.encodedBucket()}/${this.encodedKey(storageKey)}`;
    }

    private encodedBucket(): string {
        return encodeURIComponent(this.storageConfig.bucket);
    }

    private encodedKey(storageKey: string): string {
        return storageKey.split('/').map(encodeURIComponent).join('/');
    }
}

export const documentStorage = new DocumentStorage();
