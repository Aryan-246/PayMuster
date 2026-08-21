import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { AppError } from '../lib/app-error.js';
import type { DocumentStorage } from '../lib/document-storage.js';
import { prisma } from '../lib/prisma.js';
import { DocumentService } from './document.service.js';

const staffDelegate = prisma.staff as unknown as {
    findMany: typeof prisma.staff.findMany;
};
const documentDelegate = prisma.staffDocument as unknown as {
    findFirst: typeof prisma.staffDocument.findFirst;
};
const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const originalStaffFindMany = staffDelegate.findMany;
const originalDocumentFindFirst = documentDelegate.findFirst;
const originalTransaction = mutablePrisma.$transaction;

const orgId = '11111111-1111-4111-8111-111111111111';
const staffId = '22222222-2222-4222-8222-222222222222';
const userId = '33333333-3333-4333-8333-333333333333';

function assertAppError(error: unknown, expected: { code: string; status: number }): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, expected.code);
    assert.equal(error.status, expected.status);
    return true;
}

function storageStub(overrides: Partial<DocumentStorage> = {}): DocumentStorage {
    return {
        upload: async () => undefined,
        remove: async () => undefined,
        createSignedViewUrl: async () => ({ url: 'https://signed.example/document', expiresInSeconds: 300 }),
        ...overrides,
    } as DocumentStorage;
}

function validPdf(): Buffer {
    return Buffer.from('%PDF-1.7\nminimal test document');
}

afterEach(() => {
    staffDelegate.findMany = originalStaffFindMany;
    documentDelegate.findFirst = originalDocumentFindFirst;
    mutablePrisma.$transaction = originalTransaction;
});

test('document upload rejects content that does not match its declared MIME type before storage access', async () => {
    let storageCalled = false;
    const service = new DocumentService(storageStub({
        upload: async () => {
            storageCalled = true;
        },
    }));

    await assert.rejects(
        service.upload({
            userId,
            orgId,
            email: 'worker@example.com',
            documentType: 'Identity Proof',
            mimeType: 'application/pdf',
            body: Buffer.from('not a pdf'),
        }),
        (error) => assertAppError(error, { code: 'DOCUMENT_CONTENT_INVALID', status: 400 }),
    );
    assert.equal(storageCalled, false);
});

test('document ownership resolution fails closed for ambiguous staff identities', async () => {
    staffDelegate.findMany = (async () => [
        { id: staffId, orgId },
        { id: '44444444-4444-4444-8444-444444444444', orgId },
    ]) as unknown as typeof prisma.staff.findMany;
    let storageCalled = false;
    const service = new DocumentService(storageStub({
        upload: async () => {
            storageCalled = true;
        },
    }));

    await assert.rejects(
        service.upload({
            userId,
            orgId,
            email: 'worker@example.com',
            documentType: 'Identity Proof',
            mimeType: 'application/pdf',
            body: validPdf(),
        }),
        (error) => assertAppError(error, { code: 'STAFF_IDENTITY_CONFLICT', status: 409 }),
    );
    assert.equal(storageCalled, false);
});

test('inactive staff cannot upload documents or access storage', async () => {
    let staffLookup: any;
    let storageCalled = false;
    staffDelegate.findMany = (async (args: any) => {
        staffLookup = args;
        return [];
    }) as unknown as typeof prisma.staff.findMany;
    const service = new DocumentService(storageStub({
        upload: async () => {
            storageCalled = true;
        },
    }));

    await assert.rejects(
        service.upload({
            userId,
            orgId,
            email: 'worker@example.com',
            documentType: 'Identity Proof',
            mimeType: 'application/pdf',
            body: validPdf(),
        }),
        (error) => assertAppError(error, { code: 'STAFF_PROFILE_REQUIRED', status: 403 }),
    );
    assert.equal(staffLookup.where.status, 'ACTIVE');
    assert.equal(staffLookup.where.deletedAt, null);
    assert.equal(storageCalled, false);
});

test('database failure after upload removes the private object', async () => {
    staffDelegate.findMany = (async () => [{ id: staffId, orgId }]) as unknown as typeof prisma.staff.findMany;
    const calls: Array<{ operation: string; storageKey?: string }> = [];
    const service = new DocumentService(storageStub({
        upload: async (storageKey: string) => {
            calls.push({ operation: 'upload', storageKey });
        },
        remove: async (storageKey: string) => {
            calls.push({ operation: 'remove', storageKey });
        },
    }));
    mutablePrisma.$transaction = (async () => {
        throw new Error('database unavailable');
    }) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        service.upload({
            userId,
            orgId,
            email: 'worker@example.com',
            documentType: 'Identity Proof',
            mimeType: 'application/pdf',
            body: validPdf(),
        }),
        /database unavailable/,
    );
    assert.equal(calls.length, 2);
    assert.equal(calls[0].operation, 'upload');
    assert.equal(calls[1].operation, 'remove');
    assert.equal(calls[1].storageKey, calls[0].storageKey);
});

test('successful upload stores a generated private key and audit metadata atomically without returning the key', async () => {
    staffDelegate.findMany = (async () => [{ id: staffId, orgId }]) as unknown as typeof prisma.staff.findMany;
    const calls: Array<{ operation: string; args: unknown }> = [];
    let uploadedKey = '';
    const now = new Date('2026-08-17T00:00:00.000Z');
    const service = new DocumentService(storageStub({
        upload: async (storageKey: string) => {
            uploadedKey = storageKey;
        },
    }));
    const transactionClient = {
        $queryRaw: async () => undefined,
        staffDocument: {
            findFirst: async () => null,
            create: async (args: any) => {
                calls.push({ operation: 'staffDocument.create', args });
                return {
                    ...args.data,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: null,
                    deleteReason: null,
                    deletedBy: null,
                };
            },
        },
        auditLog: {
            create: async (args: unknown) => {
                calls.push({ operation: 'auditLog.create', args });
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await service.upload({
        userId,
        orgId,
        email: 'worker@example.com',
        documentType: 'Identity Proof',
        originalFilename: '../identity.pdf',
        mimeType: 'application/pdf; charset=binary',
        body: validPdf(),
        requestId: 'request-123',
    });

    assert.match(uploadedKey, new RegExp(`^${orgId}/${staffId}/[0-9a-f-]+\\.pdf$`));
    assert.deepEqual(calls.map((call) => call.operation), [
        'staffDocument.create',
        'auditLog.create',
    ]);
    assert.equal('fileUrl' in result, false);
    assert.equal(result.status, 'PENDING_REVIEW');

    const documentArgs = calls[0].args as { data: Record<string, unknown> };
    assert.equal(documentArgs.data.fileUrl, uploadedKey);
    assert.equal(documentArgs.data.orgId, orgId);
    assert.equal(documentArgs.data.staffId, staffId);

    const auditArgs = calls[1].args as {
        data: { changes: Record<string, unknown>; requestId: string };
    };
    assert.equal(auditArgs.data.requestId, 'request-123');
    assert.equal(auditArgs.data.changes.mimeType, 'application/pdf');
    assert.equal(auditArgs.data.changes.byteSize, validPdf().length);
    assert.match(String(auditArgs.data.changes.checksumSha256), /^[0-9a-f]{64}$/);
    assert.equal(auditArgs.data.changes.originalFilename, '.._identity.pdf');
});

test('an active review blocks duplicate uploads and compensates the uploaded object', async () => {
    staffDelegate.findMany = (async () => [{ id: staffId, orgId }]) as unknown as typeof prisma.staff.findMany;
    const calls: string[] = [];
    const service = new DocumentService(storageStub({
        upload: async () => {
            calls.push('upload');
        },
        remove: async () => {
            calls.push('remove');
        },
    }));
    const transactionClient = {
        $queryRaw: async () => {
            calls.push('advisory-lock');
            return undefined;
        },
        staffDocument: {
            findFirst: async (args: any) => {
                calls.push('find-active-review');
                assert.deepEqual(args.where.type, {
                    equals: 'identity proof',
                    mode: 'insensitive',
                });
                return { id: '66666666-6666-4666-8666-666666666666' };
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    await assert.rejects(
        service.upload({
            userId,
            orgId,
            email: 'worker@example.com',
            documentType: 'identity proof',
            mimeType: 'application/pdf',
            body: validPdf(),
        }),
        (error) => assertAppError(error, { code: 'DOCUMENT_REVIEW_IN_PROGRESS', status: 409 }),
    );
    assert.deepEqual(calls, ['upload', 'advisory-lock', 'find-active-review', 'remove']);
});

test('a rejected document history does not block a new submission', async () => {
    staffDelegate.findMany = (async () => [{ id: staffId, orgId }]) as unknown as typeof prisma.staff.findMany;
    const calls: string[] = [];
    const service = new DocumentService(storageStub({
        upload: async () => {
            calls.push('upload');
        },
    }));
    const transactionClient = {
        $queryRaw: async () => {
            calls.push('advisory-lock');
            return undefined;
        },
        staffDocument: {
            findFirst: async (args: any) => {
                calls.push('find-active-review');
                assert.deepEqual(args.where.status.in, ['UPLOADED', 'PENDING', 'PENDING_REVIEW', 'UNDER_REVIEW']);
                return null;
            },
            create: async (args: any) => {
                calls.push('create');
                return {
                    ...args.data,
                    createdAt: new Date('2026-08-18T00:00:00.000Z'),
                    updatedAt: new Date('2026-08-18T00:00:00.000Z'),
                    deletedAt: null,
                    deleteReason: null,
                    deletedBy: null,
                };
            },
        },
        auditLog: {
            create: async () => {
                calls.push('audit');
                return {};
            },
        },
    };
    mutablePrisma.$transaction = (async (callback: (tx: typeof transactionClient) => unknown) =>
        callback(transactionClient)) as unknown as typeof prisma.$transaction;

    const result = await service.upload({
        userId,
        orgId,
        email: 'worker@example.com',
        documentType: 'Identity Proof',
        mimeType: 'application/pdf',
        body: validPdf(),
    });

    assert.equal(result.status, 'PENDING_REVIEW');
    assert.deepEqual(calls, ['upload', 'advisory-lock', 'find-active-review', 'create', 'audit']);
});

test('a cross-owner view request returns not found without asking storage to sign', async () => {
    staffDelegate.findMany = (async () => [{ id: staffId, orgId }]) as unknown as typeof prisma.staff.findMany;
    documentDelegate.findFirst = (async () => null) as unknown as typeof prisma.staffDocument.findFirst;
    let signerCalled = false;
    const service = new DocumentService(storageStub({
        createSignedViewUrl: async () => {
            signerCalled = true;
            return { url: 'https://signed.example/document', expiresInSeconds: 300 };
        },
    }));

    await assert.rejects(
        service.createMineViewUrl('55555555-5555-4555-8555-555555555555', {
            orgId,
            email: 'worker@example.com',
        }),
        (error) => assertAppError(error, { code: 'DOCUMENT_NOT_FOUND', status: 404 }),
    );
    assert.equal(signerCalled, false);
});
