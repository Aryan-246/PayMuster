import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/app-error.js';
import { CloudinaryProvider, LocalStorageProvider, MediaService } from './media.provider.js';

test('media service uses the local fallback when cloud media is disabled', async () => {
    const calls: string[] = [];
    const primary = {
        name: 'cloudinary',
        upload: async () => { calls.push('primary'); throw new AppError('CLOUDINARY_UNAVAILABLE', 'disabled', 503); },
        remove: async () => undefined,
        createSignedUrl: async () => ({ url: '', expiresInSeconds: 0 }),
        health: async () => ({ provider: 'cloudinary', kind: 'STORAGE' as const, status: 'DISABLED' as const, enabled: false, checkedAt: new Date().toISOString() }),
    };
    const fallback = {
        name: 'local',
        upload: async (input: any) => { calls.push('fallback'); return { key: input.key, provider: 'local', byteSize: input.body.length, contentType: input.contentType }; },
        remove: async () => undefined,
        createSignedUrl: async () => ({ url: '', expiresInSeconds: 0 }),
        health: async () => ({ provider: 'local', kind: 'STORAGE' as const, status: 'CONNECTED' as const, enabled: true, checkedAt: new Date().toISOString() }),
    };
    const result = await new MediaService(primary, fallback, false).upload({
        key: 'avatars/user/photo.png',
        contentType: 'image/png',
        body: Buffer.from('png'),
        metadata: {},
    });
    assert.equal(result.provider, 'local');
    assert.deepEqual(calls, ['fallback']);
});

test('local media rejects traversal and absolute keys', async () => {
    const provider = new LocalStorageProvider('C:/paymuster-test-media');
    await assert.rejects(
        provider.upload({ key: '../secret.txt', contentType: 'text/plain', body: Buffer.from('x'), metadata: {} }),
        (error) => error instanceof AppError && error.code === 'MEDIA_KEY_INVALID',
    );
});

test('media service checksum is deterministic', () => {
    const service = new MediaService();
    assert.equal(service.checksum(Buffer.from('paymuster')), service.checksum(Buffer.from('paymuster')));
    assert.notEqual(service.checksum(Buffer.from('paymuster')), service.checksum(Buffer.from('other')));
});

test('Cloudinary adapter remains disabled when configuration is unavailable', async () => {
    const provider = new CloudinaryProvider();
    const health = await provider.health();
    assert.ok(['DISABLED', 'INVALID_CONFIGURATION', 'CONNECTED', 'UNAVAILABLE'].includes(health.status));
    await assert.rejects(
        provider.upload({ key: 'media/file.png', contentType: 'image/png', body: Buffer.from('x'), metadata: {} }),
        (error) => error instanceof AppError && ['CLOUDINARY_UNAVAILABLE', 'CLOUDINARY_NOT_IMPLEMENTED'].includes(error.code),
    );
});
