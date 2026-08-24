import { createHash } from 'node:crypto';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

import { config } from '../lib/config.js';
import { AppError } from '../lib/app-error.js';
import type { ProviderHealth, StorageObject, StorageProvider, StorageUpload } from './contracts.js';

function mediaHealth(
    provider: string,
    enabled: boolean,
    configured: boolean,
    fallback?: string,
    supported = true,
): ProviderHealth {
    return {
        provider,
        kind: 'STORAGE',
        enabled,
        status: !enabled
            ? 'DISABLED'
            : !supported
                ? 'UNAVAILABLE'
                : !configured
                    ? 'INVALID_CONFIGURATION'
                    : 'CONNECTED',
        readiness: !enabled
            ? 'DISABLED'
            : !supported
                ? 'ENVIRONMENT_BLOCKED'
                : !configured
                    ? 'MISSING_CONFIGURATION'
                    : 'READY',
        fallback,
        checkedAt: new Date().toISOString(),
    };
}

export class LocalStorageProvider implements StorageProvider {
    readonly name = 'local-storage';

    constructor(private readonly root = join(process.cwd(), '.local-media')) { }

    async upload(input: StorageUpload): Promise<StorageObject> {
        const path = this.pathFor(input.key);
        await mkdir(dirname(path), { recursive: true });
        await writeFile(path, input.body, { flag: 'wx' });
        return {
            key: input.key,
            provider: this.name,
            byteSize: input.body.byteLength,
            contentType: input.contentType,
        };
    }

    async remove(key: string): Promise<void> {
        try {
            await unlink(this.pathFor(key));
        } catch (error) {
            if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
        }
    }

    async createSignedUrl(key: string): Promise<{ url: string; expiresInSeconds: number }> {
        throw new AppError('LOCAL_MEDIA_PRIVATE', 'Local media is private and requires an authorized backend route.', 503);
    }

    async health(): Promise<ProviderHealth> {
        return mediaHealth(this.name, true, true);
    }

    private pathFor(key: string): string {
        if (!/^[a-zA-Z0-9/_-]+\.[a-zA-Z0-9]+$/.test(key) || key.includes('..') || key.startsWith('/')) {
            throw new AppError('MEDIA_KEY_INVALID', 'Media key is invalid.', 400);
        }
        return join(this.root, key);
    }

    async read(key: string): Promise<Buffer> {
        return readFile(this.pathFor(key));
    }
}

export class CloudinaryProvider implements StorageProvider {
    readonly name = 'cloudinary';

    async upload(_input: StorageUpload): Promise<StorageObject> {
        if (!config.cloudinaryEnabled || !config.cloudinaryCloudName || !config.cloudinaryApiKey || !config.cloudinaryApiSecret) {
            throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is disabled or not configured.', 503);
        }
        throw new AppError('CLOUDINARY_NOT_IMPLEMENTED', 'Cloud media adapter is intentionally disabled until free-tier configuration is verified.', 503);
    }

    async remove(_key: string): Promise<void> {
        throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is unavailable.', 503);
    }

    async createSignedUrl(_key: string): Promise<{ url: string; expiresInSeconds: number }> {
        throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is unavailable.', 503);
    }

    async health(): Promise<ProviderHealth> {
        return mediaHealth(
            this.name,
            config.cloudinaryEnabled,
            Boolean(config.cloudinaryCloudName && config.cloudinaryApiKey && config.cloudinaryApiSecret),
            'local-storage',
            false,
        );
    }
}

export class MediaService {
    constructor(
        private readonly primary: StorageProvider = new CloudinaryProvider(),
        private readonly fallback: StorageProvider = new LocalStorageProvider(),
        private readonly primaryEnabled: boolean = config.cloudinaryEnabled,
    ) { }

    async upload(input: StorageUpload): Promise<StorageObject> {
        try {
            if (this.primaryEnabled) return await this.primary.upload(input);
        } catch (error) {
            if (!(error instanceof AppError) || !['CLOUDINARY_UNAVAILABLE', 'CLOUDINARY_NOT_IMPLEMENTED'].includes(error.code)) {
                throw error;
            }
        }
        return this.fallback.upload(input);
    }

    async remove(key: string): Promise<void> {
        return this.fallback.remove(key);
    }

    async health(): Promise<ProviderHealth[]> {
        return Promise.all([this.primary.health(), this.fallback.health()]);
    }

    checksum(body: Buffer): string {
        return createHash('sha256').update(body).digest('hex');
    }
}

export const mediaService = new MediaService();
