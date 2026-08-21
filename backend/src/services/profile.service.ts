import { createHash, randomUUID } from 'node:crypto';

import { AppError } from '../lib/app-error.js';
import { config } from '../lib/config.js';
import { DocumentStorage, documentStorage } from '../lib/document-storage.js';
import { prisma } from '../lib/prisma.js';

interface ProfileStorage extends Pick<DocumentStorage, 'upload' | 'remove' | 'createSignedViewUrl'> { }

interface ProfileUser {
    id: string;
    publicId: string | null;
    email: string | null;
    phone: string | null;
    firstName: string | null;
    lastName: string | null;
    role: string;
    status: string;
    orgId: string | null;
    avatarStorageKey: string | null;
    org: { id: string; name: string; publicId: string | null } | null;
}

const profileUserSelect = {
    id: true,
    publicId: true,
    email: true,
    phone: true,
    firstName: true,
    lastName: true,
    role: true,
    status: true,
    orgId: true,
    avatarStorageKey: true,
    org: { select: { id: true, name: true, publicId: true } },
} as const;

const avatarExtensionByMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
} as const;

function normalizeName(value: string): { firstName: string; lastName: string | null } {
    const parts = value.trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) {
        throw new AppError('PROFILE_NAME_REQUIRED', 'Full name is required.', 400);
    }
    return { firstName: parts[0], lastName: parts.slice(1).join(' ') || null };
}

function normalizePhone(value: string | null | undefined): string | null {
    const phone = value?.trim() ?? '';
    if (!phone) return null;
    if (!/^[+0-9 ()-]{7,30}$/.test(phone)) {
        throw new AppError('PROFILE_PHONE_INVALID', 'Phone number format is invalid.', 400);
    }
    return phone;
}

function hasExpectedSignature(mimeType: string, body: Buffer): boolean {
    if (mimeType === 'image/png') {
        return body.length >= 8 && body.subarray(0, 8).equals(
            Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        );
    }
    return mimeType === 'image/jpeg' && body.length >= 4 &&
        body[0] === 0xff && body[1] === 0xd8 &&
        body[body.length - 2] === 0xff && body[body.length - 1] === 0xd9;
}

function displayName(user: Pick<ProfileUser, 'firstName' | 'lastName' | 'email'>): string {
    return [user.firstName, user.lastName].filter(Boolean).join(' ').trim() || user.email || 'User';
}

export class ProfileService {
    constructor(private readonly storage: ProfileStorage = documentStorage) { }

    async getProfile(userId: string) {
        const user = await prisma.user.findUnique({ where: { id: userId }, select: profileUserSelect });
        if (!user) throw new AppError('PROFILE_NOT_FOUND', 'Profile not found.', 404);
        return this.toProfile(user);
    }

    async updateProfile(userId: string, input: { name: string; phone?: string | null }) {
        const { firstName, lastName } = normalizeName(input.name);
        const phone = normalizePhone(input.phone);
        const current = await prisma.user.findUnique({ where: { id: userId }, select: profileUserSelect });
        if (!current) throw new AppError('PROFILE_NOT_FOUND', 'Profile not found.', 404);

        const updated = await prisma.$transaction(async (tx) => {
            const result = await tx.user.update({
                where: { id: userId },
                data: { firstName, lastName, phone },
                select: profileUserSelect,
            });
            await tx.auditLog.create({
                data: {
                    action: 'UPDATE',
                    entityType: 'UserProfile',
                    entityId: userId,
                    userId,
                    orgId: current.orgId,
                    targetId: userId,
                    beforeValue: {
                        firstName: current.firstName,
                        lastName: current.lastName,
                        phone: current.phone,
                    },
                    afterValue: { firstName, lastName, phone },
                    changes: { fields: ['firstName', 'lastName', 'phone'] },
                },
            });
            return result;
        });
        return this.toProfile(updated);
    }

    async uploadAvatar(userId: string, input: { mimeType: string; body: Buffer }) {
        const mimeType = input.mimeType.split(';', 1)[0].trim().toLowerCase();
        const extension = avatarExtensionByMime[mimeType as keyof typeof avatarExtensionByMime];
        if (!extension) throw new AppError('AVATAR_MIME_TYPE_NOT_ALLOWED', 'Only JPEG and PNG avatars are accepted.', 415);
        if (input.body.length === 0) throw new AppError('AVATAR_EMPTY', 'The selected avatar is empty.', 400);
        if (input.body.length > config.avatarUploadMaxBytes) {
            throw new AppError('AVATAR_TOO_LARGE', `Avatars must not exceed ${config.avatarUploadMaxBytes} bytes.`, 413);
        }
        if (!hasExpectedSignature(mimeType, input.body)) {
            throw new AppError('AVATAR_CONTENT_INVALID', 'The file content does not match its declared image type.', 400);
        }

        const current = await prisma.user.findUnique({ where: { id: userId }, select: { id: true, orgId: true, avatarStorageKey: true } });
        if (!current) throw new AppError('PROFILE_NOT_FOUND', 'Profile not found.', 404);
        const storageKey = `avatars/${userId}/${randomUUID()}.${extension}`;
        const checksum = createHash('sha256').update(input.body).digest('hex');
        await this.storage.upload(storageKey, mimeType, input.body);

        try {
            const updated = await prisma.$transaction(async (tx) => {
                const result = await tx.user.update({
                    where: { id: userId },
                    data: { avatarStorageKey: storageKey, avatarUrl: null },
                    select: profileUserSelect,
                });
                await tx.auditLog.create({
                    data: {
                        action: 'UPDATE',
                        entityType: 'UserProfile',
                        entityId: userId,
                        userId,
                        orgId: current.orgId,
                        targetId: userId,
                        changes: { field: 'avatar', replaced: Boolean(current.avatarStorageKey), checksumSha256: checksum, mimeType, byteSize: input.body.length },
                    },
                });
                return result;
            });
            if (current.avatarStorageKey) {
                try { await this.storage.remove(current.avatarStorageKey); } catch { /* retain old private object if cleanup is temporarily unavailable */ }
            }
            return this.toProfile(updated);
        } catch (error) {
            try { await this.storage.remove(storageKey); } catch { /* compensation is best effort */ }
            throw error;
        }
    }

    private async toProfile(user: ProfileUser) {
        const documents = user.orgId
            ? await prisma.staffDocument.findMany({
                where: { orgId: user.orgId, deletedAt: null, staff: { email: { equals: user.email ?? '', mode: 'insensitive' } } },
                select: { id: true, type: true, status: true, createdAt: true, updatedAt: true, reviewerId: true, reviewedAt: true, rejectionReason: true, version: true, parentDocumentId: true, resubmissionCount: true },
                orderBy: { createdAt: 'desc' },
            })
            : [];
        const avatar = user.avatarStorageKey
            ? await this.storage.createSignedViewUrl(user.avatarStorageKey)
            : null;
        return {
            id: user.id,
            publicId: user.publicId,
            email: user.email,
            phone: user.phone,
            name: displayName(user),
            firstName: user.firstName,
            lastName: user.lastName,
            role: user.role,
            status: user.status,
            organization: user.org,
            avatarUrl: avatar?.url ?? null,
            avatarExpiresInSeconds: avatar?.expiresInSeconds ?? null,
            documents,
            verification: {
                total: documents.length,
                verified: documents.filter((document) => document.status === 'VERIFIED').length,
                pending: documents.filter((document) => ['PENDING', 'PENDING_REVIEW', 'UNDER_REVIEW'].includes(document.status)).length,
                rejected: documents.filter((document) => document.status === 'REJECTED').length,
            },
        };
    }
}

export const profileService = new ProfileService();
