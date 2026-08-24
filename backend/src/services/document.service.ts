import { createHash, randomUUID } from 'node:crypto';

import type { StaffDocument } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { config } from '../lib/config.js';
import { DocumentStorage, documentStorage } from '../lib/document-storage.js';
import { logger } from '../lib/logger.js';
import { prisma } from '../lib/prisma.js';
import { subscriptionService } from './subscription.service.js';

interface UploadDocumentInput {
    userId: string;
    orgId: string | null;
    email: string;
    documentType: string;
    parentDocumentId?: string;
    originalFilename?: string;
    mimeType: string;
    expiryDate?: string;
    body: Buffer;
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
}

interface DocumentSummary {
    id: string;
    orgId: string;
    staffId: string;
    type: string;
    status: StaffDocument['status'];
    expiryDate: Date | null;
    createdAt: Date;
    updatedAt: Date;
    reviewerId: string | null;
    reviewedAt: Date | null;
    rejectionReason: string | null;
    version: number;
    parentDocumentId: string | null;
    resubmissionCount: number;
    originalFilename: string | null;
    mimeType: string | null;
    byteSize: number | null;
    sizeWarning?: boolean;
}

const extensionByMimeType: Readonly<Record<string, string>> = Object.freeze({
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
    'application/msword': 'doc',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.ms-powerpoint': 'ppt',
});

const officeMimeTypes: ReadonlySet<string> = new Set([
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
]);

type DocumentSizeCategory = 'image' | 'pdf' | 'office';

// Maps an allowlisted MIME type to its configurable size tier. Only known
// document types reach this (audio/video are rejected earlier); the fallback
// keeps the most conservative tier for any future allowlist entry.
function sizeCategoryFor(mimeType: string): DocumentSizeCategory {
    if (mimeType === 'application/pdf') return 'pdf';
    if (officeMimeTypes.has(mimeType)) return 'office';
    if (mimeType.startsWith('image/')) return 'image';
    return 'image';
}

function normalizeMimeType(value: string): string {
    return value.split(';', 1)[0].trim().toLowerCase();
}

function hasExpectedSignature(mimeType: string, body: Buffer): boolean {
    if (mimeType === 'application/pdf') {
        return body.length >= 5 && body.subarray(0, 5).toString('ascii') === '%PDF-';
    }
    if (mimeType === 'image/png') {
        return body.length >= 8 && body.subarray(0, 8).equals(
            Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        );
    }
    if (mimeType === 'image/jpeg') {
        return body.length >= 4 &&
            body[0] === 0xff &&
            body[1] === 0xd8 &&
            body[body.length - 2] === 0xff &&
            body[body.length - 1] === 0xd9;
    }
    if (officeMimeTypes.has(mimeType)) {
        // OOXML (docx/xlsx/pptx) are ZIP containers: "PK" + local/empty/spanned marker.
        if (mimeType.startsWith('application/vnd.openxmlformats-')) {
            return body.length >= 4 &&
                body[0] === 0x50 && body[1] === 0x4b &&
                (body[2] === 0x03 || body[2] === 0x05 || body[2] === 0x07);
        }
        // Legacy OLE2 compound files (doc/xls/ppt): D0 CF 11 E0 A1 B1 1A E1.
        return body.length >= 8 && body.subarray(0, 8).equals(
            Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
        );
    }
    return false;
}

function documentSummary(document: StaffDocument): DocumentSummary {
    return {
        id: document.id,
        orgId: document.orgId,
        staffId: document.staffId,
        type: document.type,
        status: document.status,
        expiryDate: document.expiryDate,
        createdAt: document.createdAt,
        updatedAt: document.updatedAt,
        reviewerId: document.reviewerId,
        reviewedAt: document.reviewedAt,
        rejectionReason: document.rejectionReason,
        version: document.version,
        parentDocumentId: document.parentDocumentId,
        resubmissionCount: document.resubmissionCount,
        originalFilename: document.originalFilename,
        mimeType: document.mimeType,
        byteSize: document.byteSize,
    };
}

export class DocumentService {
    constructor(private readonly storage: DocumentStorage = documentStorage) { }

    async listMine(user: { orgId: string | null; email: string }): Promise<DocumentSummary[]> {
        const staff = await this.resolveStaff(user.orgId, user.email);
        const documents = await prisma.staffDocument.findMany({
            where: {
                orgId: staff.orgId,
                staffId: staff.id,
                deletedAt: null,
            },
            orderBy: { createdAt: 'desc' },
        });
        return documents.map(documentSummary);
    }

    async upload(input: UploadDocumentInput): Promise<DocumentSummary> {
        const documentType = input.documentType.trim();
        if (!/^[a-zA-Z0-9][a-zA-Z0-9 ()_./-]{1,79}$/.test(documentType)) {
            throw new AppError(
                'DOCUMENT_TYPE_INVALID',
                'Document type must be between 2 and 80 supported characters.',
                400,
            );
        }

        const mimeType = normalizeMimeType(input.mimeType);
        // Audio and video are served by the separate media-private architecture
        // and must never be written to the staff-documents-private bucket.
        if (mimeType.startsWith('audio/') || mimeType.startsWith('video/')) {
            throw new AppError(
                'DOCUMENT_MEDIA_NOT_ALLOWED',
                'Audio and video files are handled by the separate media library, not the document store.',
                415,
            );
        }
        if (!config.documentAllowedMimeTypes.includes(mimeType)) {
            throw new AppError(
                'DOCUMENT_MIME_TYPE_NOT_ALLOWED',
                'This file type is not in the configured document upload allowlist.',
                415,
            );
        }
        if (input.body.length === 0) {
            throw new AppError('DOCUMENT_EMPTY', 'The uploaded document is empty.', 400);
        }
        // Per-category size tiers (all configurable). The hard cap is clamped to
        // the bucket-wide maximum so staff-documents-private never stores an
        // object larger than DOCUMENT_UPLOAD_MAX_BYTES (10 MB).
        const sizeCategory = sizeCategoryFor(mimeType);
        const tier = config.documentSizePolicy[sizeCategory];
        const hardMaxBytes = Math.min(tier.max, config.documentUploadMaxBytes);
        if (input.body.length > hardMaxBytes) {
            throw new AppError(
                'DOCUMENT_TOO_LARGE',
                `Documents of type ${mimeType} must not exceed ${(hardMaxBytes / (1024 * 1024)).toFixed(0)} MB.`,
                413,
            );
        }
        // Soft warning tier: accepted, but surfaced so the client can advise
        // the user the file is larger than recommended.
        const sizeWarning = input.body.length > tier.warn;
        if (!hasExpectedSignature(mimeType, input.body)) {
            throw new AppError(
                'DOCUMENT_CONTENT_INVALID',
                'The file content does not match its declared type.',
                400,
            );
        }

        const staff = await this.resolveStaff(input.orgId, input.email);
        
        // Storage Quota Enforcement
        const access = await subscriptionService.getFeatureAccess(staff.orgId, 'document_storage_upload');
        if (!access.allowed) {
            throw new AppError('STORAGE_QUOTA_EXCEEDED', 'Storage quota exceeded. Please upgrade your plan to upload more documents.', 403);
        }
        if (!access.unlimited) {
            const limit = access.limit ?? 10;
            const d = new Date();
            const monthStart = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1, 0, 0, 0));
            const uploadCount = await prisma.auditLog.count({
                where: {
                    entityType: 'StaffDocument',
                    orgId: staff.orgId,
                    action: 'CREATE',
                    createdAt: { gte: monthStart },
                }
            });
            if (uploadCount >= limit) {
                throw new AppError('STORAGE_QUOTA_EXCEEDED', `Free allowance of ${limit} uploads per month reached. Please upgrade to continue.`, 403);
            }
        }

        const expiryDate = this.parseExpiryDate(input.expiryDate);
        const documentId = randomUUID();
        const extension = extensionByMimeType[mimeType];
        const storageKey = `${staff.orgId}/${staff.id}/${documentId}.${extension}`;
        const checksum = createHash('sha256').update(input.body).digest('hex');
        const originalFilename = this.sanitizeFilename(input.originalFilename, extension);

        await this.storage.upload(storageKey, mimeType, input.body);

        try {
            const document = await prisma.$transaction(async (tx) => {
                await tx.$executeRaw`
                    SELECT pg_advisory_xact_lock(
                        hashtextextended(${`staff-document:${staff.orgId}:${staff.id}:${documentType.toLowerCase()}`}, 0)
                    )
                `;

                const existing = await tx.staffDocument.findFirst({
                    where: {
                        orgId: staff.orgId,
                        staffId: staff.id,
                        type: { equals: documentType, mode: 'insensitive' },
                        status: { in: ['UPLOADED', 'PENDING', 'PENDING_REVIEW', 'UNDER_REVIEW'] },
                        deletedAt: null,
                    },
                    select: { id: true },
                });
                if (existing) {
                    throw new AppError(
                        'DOCUMENT_REVIEW_IN_PROGRESS',
                        'A document of this type is already awaiting review.',
                        409,
                    );
                }

                let parent: Pick<StaffDocument, 'id' | 'orgId' | 'staffId' | 'type' | 'status' | 'version' | 'resubmissionCount'> | null = null;
                if (input.parentDocumentId) {
                    parent = await tx.staffDocument.findFirst({
                        where: {
                            id: input.parentDocumentId,
                            orgId: staff.orgId,
                            staffId: staff.id,
                            deletedAt: null,
                        },
                        select: {
                            id: true,
                            orgId: true,
                            staffId: true,
                            type: true,
                            status: true,
                            version: true,
                            resubmissionCount: true,
                        },
                    });
                    if (!parent || parent.status !== 'REJECTED' || parent.type.toLowerCase() !== documentType.toLowerCase()) {
                        throw new AppError(
                            'DOCUMENT_RESUBMISSION_INVALID',
                            'Only a rejected document of the same type can be resubmitted.',
                            409,
                        );
                    }
                }

                const created = await tx.staffDocument.create({
                    data: {
                        id: documentId,
                        orgId: staff.orgId,
                        staffId: staff.id,
                        type: documentType,
                        fileUrl: storageKey,
                        expiryDate,
                        status: 'PENDING_REVIEW',
                        parentDocumentId: parent?.id,
                        version: parent ? parent.version + 1 : 1,
                        resubmissionCount: parent ? parent.resubmissionCount + 1 : 0,
                        originalFilename,
                        mimeType,
                        byteSize: input.body.length,
                        checksumSha256: checksum,
                    },
                });
                await tx.auditLog.create({
                    data: {
                        orgId: staff.orgId,
                        userId: input.userId,
                        action: 'CREATE',
                        entityType: 'StaffDocument',
                        entityId: documentId,
                        requestId: input.requestId,
                        ipAddress: input.ipAddress,
                        userAgent: input.userAgent,
                        changes: {
                            status: 'PENDING_REVIEW',
                            documentType,
                            parentDocumentId: parent?.id ?? null,
                            version: parent ? parent.version + 1 : 1,
                            resubmissionCount: parent ? parent.resubmissionCount + 1 : 0,
                            originalFilename,
                            mimeType,
                            byteSize: input.body.length,
                            checksumSha256: checksum,
                            sizeWarning,
                            expiryDate: expiryDate?.toISOString() ?? null,
                        },
                    },
                });
                return created;
            });
            return { ...documentSummary(document), sizeWarning };
        } catch (error) {
            try {
                await this.storage.remove(storageKey);
            } catch (cleanupError) {
                logger.error('document.upload_compensation_failed', cleanupError, {
                    documentId,
                    orgId: staff.orgId,
                });
            }
            throw error;
        }
    }

    async createMineViewUrl(
        documentId: string,
        user: { orgId: string | null; email: string },
    ): Promise<{ url: string; expiresInSeconds: number }> {
        const staff = await this.resolveStaff(user.orgId, user.email);
        const document = await prisma.staffDocument.findFirst({
            where: {
                id: documentId,
                orgId: staff.orgId,
                staffId: staff.id,
                deletedAt: null,
            },
            select: { fileUrl: true },
        });
        if (!document) {
            throw new AppError('DOCUMENT_NOT_FOUND', 'Document not found.', 404);
        }
        return this.storage.createSignedViewUrl(document.fileUrl);
    }

    async createAdminViewUrl(documentId: string): Promise<{ url: string; expiresInSeconds: number }> {
        const document = await prisma.staffDocument.findFirst({
            where: { id: documentId, deletedAt: null },
            select: { fileUrl: true },
        });
        if (!document) {
            throw new AppError('DOCUMENT_NOT_FOUND', 'Document not found.', 404);
        }
        return this.storage.createSignedViewUrl(document.fileUrl);
    }

    private async resolveStaff(orgId: string | null, email: string): Promise<{ id: string; orgId: string }> {
        if (!orgId || !email.trim()) {
            throw new AppError(
                'STAFF_PROFILE_REQUIRED',
                'An active company staff profile is required to manage documents.',
                403,
            );
        }

        const matches = await prisma.staff.findMany({
            where: {
                orgId,
                email: { equals: email.trim(), mode: 'insensitive' },
                status: 'ACTIVE',
                deletedAt: null,
            },
            select: { id: true, orgId: true },
            take: 2,
        });
        if (matches.length === 0) {
            throw new AppError(
                'STAFF_PROFILE_REQUIRED',
                'An active company staff profile is required to manage documents.',
                403,
            );
        }
        if (matches.length > 1) {
            throw new AppError(
                'STAFF_IDENTITY_CONFLICT',
                'This staff identity is ambiguous and requires administrator review.',
                409,
            );
        }
        return matches[0];
    }

    private parseExpiryDate(value?: string): Date | null {
        if (!value?.trim()) {
            return null;
        }
        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) {
            throw new AppError('DOCUMENT_EXPIRY_INVALID', 'Document expiry date is invalid.', 400);
        }
        return parsed;
    }

    private sanitizeFilename(value: string | undefined, extension: string): string {
        const filename = value?.trim().replace(/[\\/\u0000-\u001f\u007f]/g, '_');
        return filename ? filename.slice(0, 160) : `document.${extension}`;
    }
}

export const documentService = new DocumentService();
