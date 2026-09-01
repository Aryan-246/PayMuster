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
    // Hermetic: a clientFactory of null forces the "SDK/config unavailable"
    // path without ever touching real credentials or the network.
    const provider = new CloudinaryProvider({ clientFactory: () => null });
    const health = await provider.health();
    assert.ok(['DISABLED', 'INVALID_CONFIGURATION', 'UNAVAILABLE'].includes(health.status));
    await assert.rejects(
        provider.upload({ key: 'media/file.png', contentType: 'image/png', body: Buffer.from('x'), metadata: {} }),
        (error) => error instanceof AppError && error.code === 'CLOUDINARY_UNAVAILABLE',
    );
});

function makeFakeCloudinaryClient() {
    const calls: Array<{ op: string; args: any }> = [];
    const client = {
        uploader: {
            upload: async (dataUri: string, options: any) => {
                calls.push({ op: 'upload', args: { dataUri, options } });
                return { public_id: options.public_id, bytes: 1, format: 'png' };
            },
            destroy: async (publicId: string, options: any) => {
                calls.push({ op: 'destroy', args: { publicId, options } });
                return { result: 'ok' };
            },
        },
        utils: {
            url: (publicId: string, options: any) => {
                calls.push({ op: 'url', args: { publicId, options } });
                return `https://res.cloudinary.com/demo/image/authenticated/${publicId}?s=1`;
            },
        },
    };
    return { client, calls };
}

test('Cloudinary upload stores the asset privately under the derived public id', async () => {
    const { client, calls } = makeFakeCloudinaryClient();
    const provider = new CloudinaryProvider({ clientFactory: () => client });

    const result = await provider.upload({
        key: 'avatars/org/photo.png',
        contentType: 'image/png',
        body: Buffer.from('png'),
        metadata: {},
    });

    assert.equal(result.provider, 'cloudinary');
    assert.equal(result.key, 'avatars/org/photo.png');
    assert.equal(result.byteSize, 3);
    assert.equal(result.contentType, 'image/png');

    const upload = calls.find((c) => c.op === 'upload');
    assert.ok(upload);
    // Typed (image) assets strip the extension from the public id.
    assert.equal(upload.args.options.public_id, 'avatars/org/photo');
    assert.equal(upload.args.options.resource_type, 'image');
    // Private delivery: only signed URLs minted server-side can fetch it.
    assert.equal(upload.args.options.type, 'authenticated');
    assert.equal(upload.args.options.overwrite, false);
    // The body travels as a data URI carrying the declared content type.
    assert.ok(upload.args.dataUri.startsWith('data:image/png;base64,'));
});

test('Cloudinary keeps the extension for raw (non-media) assets', async () => {
    const { client, calls } = makeFakeCloudinaryClient();
    const provider = new CloudinaryProvider({ clientFactory: () => client });

    await provider.upload({
        key: 'documents/org/contract.pdf',
        contentType: 'application/pdf',
        body: Buffer.from('%PDF-1.4'),
        metadata: {},
    });

    const upload = calls.find((c) => c.op === 'upload');
    assert.ok(upload);
    assert.equal(upload.args.options.public_id, 'documents/org/contract.pdf');
    assert.equal(upload.args.options.resource_type, 'raw');
    assert.equal(upload.args.options.type, 'authenticated');
});

test('Cloudinary rejects invalid keys before touching the provider', async () => {
    const { client, calls } = makeFakeCloudinaryClient();
    const provider = new CloudinaryProvider({ clientFactory: () => client });

    await assert.rejects(
        provider.upload({ key: '../escape.png', contentType: 'image/png', body: Buffer.from('x'), metadata: {} }),
        (error) => error instanceof AppError && error.code === 'MEDIA_KEY_INVALID',
    );
    await assert.rejects(
        provider.remove('no-extension'),
        (error) => error instanceof AppError && error.code === 'MEDIA_KEY_INVALID',
    );
    assert.equal(calls.length, 0);
});

test('Cloudinary remove destroys the asset and tolerates already-removed files', async () => {
    const { client, calls } = makeFakeCloudinaryClient();
    const provider = new CloudinaryProvider({ clientFactory: () => client });

    await provider.remove('avatars/org/photo.png');
    let destroy = calls.find((c) => c.op === 'destroy');
    assert.ok(destroy);
    assert.equal(destroy.args.publicId, 'avatars/org/photo');
    assert.equal(destroy.args.options.resource_type, 'image');
    assert.equal(destroy.args.options.type, 'authenticated');

    // "not found" is a successful no-op (idempotent remove), not an error.
    client.uploader.destroy = async () => ({ result: 'not found' });
    await provider.remove('avatars/org/other.png');
});

test('Cloudinary signed URLs are https, bounded, and derived from the extension', async () => {
    const { client, calls } = makeFakeCloudinaryClient();
    const provider = new CloudinaryProvider({ clientFactory: () => client });

    const { url, expiresInSeconds } = await provider.createSignedUrl('avatars/org/photo.png', 0);
    assert.ok(url.startsWith('https://'));
    assert.equal(expiresInSeconds, 300);

    const signed = calls.find((c) => c.op === 'url');
    assert.ok(signed);
    assert.equal(signed.args.options.type, 'authenticated');
    assert.equal(signed.args.options.sign_url, true);
    assert.equal(signed.args.options.resource_type, 'image');
    assert.equal(signed.args.options.format, 'png');
    assert.ok(typeof signed.args.options.expires_at === 'number');
});

test('Cloudinary health reports honest SDK availability', async () => {
    // Hermetic: with no client available the provider must degrade honestly
    // instead of claiming connected — never a fabricated state.
    const provider = new CloudinaryProvider({ clientFactory: () => null });
    const health = await provider.health();
    assert.ok(['DISABLED', 'INVALID_CONFIGURATION', 'UNAVAILABLE'].includes(health.status));
    assert.equal(health.fallback, 'local-storage');
});
