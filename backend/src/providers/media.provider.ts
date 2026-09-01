import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

import { config } from '../lib/config.js';
import { AppError } from '../lib/app-error.js';
import { logger } from '../lib/logger.js';
import type { ProviderHealth, StorageObject, StorageProvider, StorageUpload } from './contracts.js';

const require = createRequire(import.meta.url);

const SIGNED_URL_TTL_SECONDS = 300;

const IMAGE_EXTENSIONS = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'tiff', 'ico', 'avif', 'heic']);
const VIDEO_EXTENSIONS = new Set(['mp4', 'webm', 'mov', 'avi', 'mkv', 'm4v', 'mpeg', 'mpg']);

function validateMediaKey(key: string): string {
    if (!/^[a-zA-Z0-9/_-]+\.[a-zA-Z0-9]+$/.test(key) || key.includes('..') || key.startsWith('/')) {
        throw new AppError('MEDIA_KEY_INVALID', 'Media key is invalid.', 400);
    }
    return key;
}

function keyExtension(key: string): string {
    return key.slice(key.lastIndexOf('.') + 1).toLowerCase();
}

/**
 * Maps an upload content type to the Cloudinary resource type. Images and
 * videos use Cloudinary's typed delivery pipeline; everything else (PDFs,
 * spreadsheets, arbitrary files) is stored as a raw asset.
 */
function resourceTypeForContentType(contentType: string): 'image' | 'video' | 'raw' {
    if (contentType.startsWith('image/')) return 'image';
    if (contentType.startsWith('video/')) return 'video';
    return 'raw';
}

/** Derives the resource type from the key extension when no content type is at hand (remove/sign). */
function resourceTypeForKey(key: string): 'image' | 'video' | 'raw' {
    const ext = keyExtension(key);
    if (IMAGE_EXTENSIONS.has(ext)) return 'image';
    if (VIDEO_EXTENSIONS.has(ext)) return 'video';
    return 'raw';
}

/**
 * Cloudinary addresses assets by public_id. Typed (image/video) assets strip
 * the extension — Cloudinary re-adds the derived format — while raw assets
 * keep it, because the extension is part of the raw asset's identity.
 */
function cloudinaryPublicId(key: string, resourceType: 'image' | 'video' | 'raw'): string {
    if (resourceType === 'raw') return key;
    const slash = key.lastIndexOf('/');
    const dot = key.lastIndexOf('.');
    return dot > slash ? key.slice(0, dot) : key;
}

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
        return join(this.root, validateMediaKey(key));
    }

    async read(key: string): Promise<Buffer> {
        return readFile(this.pathFor(key));
    }
}

export interface CloudinaryProviderOptions {
    /** Test seam: overrides how the Cloudinary SDK client is obtained. */
    clientFactory?: () => any | null;
}

export class CloudinaryProvider implements StorageProvider {
    readonly name = 'cloudinary';
    private sdk: any | null = null;
    private sdkError: string | null = null;
    private readonly clientFactory: () => any | null;

    constructor(options: CloudinaryProviderOptions = {}) {
        this.clientFactory = options.clientFactory ?? (() => this.loadClient());
    }

    private isConfigured(): boolean {
        return Boolean(
            config.cloudinaryEnabled &&
            config.cloudinaryCloudName &&
            config.cloudinaryApiKey &&
            config.cloudinaryApiSecret,
        );
    }

    /**
     * Lazily loads and configures the Cloudinary SDK (blueprint §K). Returns
     * null — never a fabricated client — when the SDK is missing or the
     * configuration is incomplete, so callers surface an honest state and the
     * local-storage fallback stays authoritative.
     */
    private getClient(): any | null {
        if (this.sdk) return this.sdk;
        if (this.sdkError) return null;
        const client = this.clientFactory();
        if (!client) return null;
        this.sdk = client;
        return this.sdk;
    }

    private loadClient(): any | null {
        if (!this.isConfigured()) {
            this.sdkError = 'Cloudinary is disabled or its credentials are incomplete.';
            return null;
        }
        try {
            const cloudinary = require('cloudinary');
            const v2 = cloudinary.v2 ?? cloudinary.default?.v2 ?? cloudinary;
            v2.config({
                cloud_name: config.cloudinaryCloudName,
                api_key: config.cloudinaryApiKey,
                api_secret: config.cloudinaryApiSecret,
                secure: true,
            });
            return v2;
        } catch (err: any) {
            this.sdkError = `cloudinary SDK unavailable: ${err.message}`;
            logger.error('cloudinary.sdk_init_failed', err);
            return null;
        }
    }

    async upload(input: StorageUpload): Promise<StorageObject> {
        validateMediaKey(input.key);
        const client = this.getClient();
        if (!client) {
            throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is disabled or not configured.', 503);
        }

        const resourceType = resourceTypeForContentType(input.contentType);
        const publicId = cloudinaryPublicId(input.key, resourceType);
        try {
            const dataUri = `data:${input.contentType};base64,${input.body.toString('base64')}`;
            // type 'authenticated' keeps assets private: they are only
            // retrievable through signed delivery URLs minted server-side.
            const result = await client.uploader.upload(dataUri, {
                public_id: publicId,
                resource_type: resourceType,
                type: 'authenticated',
                overwrite: false,
                unique_filename: false,
            });
            if (typeof result?.public_id !== 'string' || result.public_id !== publicId) {
                throw new AppError('CLOUDINARY_INVALID_RESPONSE', 'Cloud media provider returned an invalid upload response.', 502);
            }
            return {
                key: input.key,
                provider: this.name,
                byteSize: input.body.byteLength,
                contentType: input.contentType,
            };
        } catch (error) {
            if (error instanceof AppError) throw error;
            logger.error('cloudinary.upload_failed', error as Error, { key: input.key });
            throw new AppError('CLOUDINARY_UPLOAD_FAILED', 'Cloud media provider could not store the file.', 502);
        }
    }

    async remove(key: string): Promise<void> {
        validateMediaKey(key);
        const client = this.getClient();
        if (!client) {
            throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is unavailable.', 503);
        }

        const resourceType = resourceTypeForKey(key);
        try {
            const result = await client.uploader.destroy(cloudinaryPublicId(key, resourceType), {
                resource_type: resourceType,
                type: 'authenticated',
                invalidate: true,
            });
            if (result?.result !== 'ok' && result?.result !== 'not found') {
                throw new AppError('CLOUDINARY_INVALID_RESPONSE', 'Cloud media provider returned an invalid removal response.', 502);
            }
        } catch (error) {
            if (error instanceof AppError) throw error;
            logger.error('cloudinary.remove_failed', error as Error, { key });
            throw new AppError('CLOUDINARY_REMOVE_FAILED', 'Cloud media provider could not remove the file.', 502);
        }
    }

    async createSignedUrl(key: string, expiresInSeconds: number): Promise<{ url: string; expiresInSeconds: number }> {
        validateMediaKey(key);
        const client = this.getClient();
        if (!client) {
            throw new AppError('CLOUDINARY_UNAVAILABLE', 'Cloud media provider is unavailable.', 503);
        }

        const ttl = Math.min(Math.max(30, Math.floor(expiresInSeconds || SIGNED_URL_TTL_SECONDS)), 3600);
        const resourceType = resourceTypeForKey(key);
        try {
            const url: unknown = client.utils.url(cloudinaryPublicId(key, resourceType), {
                type: 'authenticated',
                sign_url: true,
                resource_type: resourceType,
                ...(resourceType === 'raw' ? {} : { format: keyExtension(key) }),
                expires_at: Math.floor(Date.now() / 1000) + ttl,
            });
            if (typeof url !== 'string' || !url.startsWith('https://')) {
                throw new AppError('CLOUDINARY_INVALID_RESPONSE', 'Cloud media provider could not produce a delivery URL.', 502);
            }
            return { url, expiresInSeconds: ttl };
        } catch (error) {
            if (error instanceof AppError) throw error;
            logger.error('cloudinary.signed_url_failed', error as Error, { key });
            throw new AppError('CLOUDINARY_SIGNED_URL_FAILED', 'Cloud media provider could not produce a delivery URL.', 502);
        }
    }

    async health(): Promise<ProviderHealth> {
        const enabled = config.cloudinaryEnabled;
        const credentialsPresent = Boolean(config.cloudinaryCloudName && config.cloudinaryApiKey && config.cloudinaryApiSecret);
        const client = enabled && credentialsPresent ? this.getClient() : null;
        return {
            provider: this.name,
            kind: 'STORAGE',
            enabled,
            status: !enabled
                ? 'DISABLED'
                : !credentialsPresent
                    ? 'INVALID_CONFIGURATION'
                    : client
                        ? 'CONNECTED'
                        : 'UNAVAILABLE',
            readiness: !enabled
                ? 'DISABLED'
                : !credentialsPresent
                    ? 'MISSING_CONFIGURATION'
                    : client
                        ? 'READY'
                        : 'ENVIRONMENT_BLOCKED',
            fallback: 'local-storage',
            checkedAt: new Date().toISOString(),
            detail: !enabled
                ? 'Cloud media is disabled; local private storage remains authoritative.'
                : !credentialsPresent
                    ? 'Cloudinary credentials are incomplete.'
                    : client
                        ? 'Cloudinary is configured; private uploads with signed delivery are active.'
                        : this.sdkError || 'Cloudinary SDK could not be initialized.',
        };
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

    async createSignedUrl(key: string, expiresInSeconds: number): Promise<{ url: string; expiresInSeconds: number }> {
        if (this.primaryEnabled) {
            return this.primary.createSignedUrl(key, expiresInSeconds);
        }
        return this.fallback.createSignedUrl(key, expiresInSeconds);
    }

    async health(): Promise<ProviderHealth[]> {
        return Promise.all([this.primary.health(), this.fallback.health()]);
    }

    checksum(body: Buffer): string {
        return createHash('sha256').update(body).digest('hex');
    }
}

export const mediaService = new MediaService();
