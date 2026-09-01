import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { allocateNextPublicId } from '../lib/public-id.js';

const REVIEW_TEXT_MAX = 2000;
const REVIEW_TEXT_MIN = 5;

export interface SubmitReviewInput {
    userId: string;
    orgId: string;
    rating: number;
    text: string;
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
}

export interface ModerateReviewInput {
    reviewId: string;
    adminId: string;
    action: 'PUBLISH' | 'HIDE' | 'FLAG' | 'RESPOND';
    response?: string;
    requestId?: string;
    ipAddress?: string;
    userAgent?: string;
}

export interface ReviewSummary {
    total: number;
    average: number;
    distribution: Record<number, number>;
    pendingCount: number;
    publishedCount: number;
    hiddenCount: number;
    flaggedCount: number;
}

/** Injectable database surface (defaults to the real Prisma client). */
type ReviewDb = {
    review: any;
    user: any;
    org: any;
    auditLog: any;
    notification: any;
    $transaction: any;
    publicIdSequence?: any;
};

const NEXT_STATUS: Record<'PUBLISH' | 'HIDE' | 'FLAG', 'PUBLISHED' | 'HIDDEN' | 'FLAGGED'> = {
    PUBLISH: 'PUBLISHED',
    HIDE: 'HIDDEN',
    FLAG: 'FLAGGED',
};

/**
 * Review Service — customer reviews with server-authoritative moderation.
 *
 * Submit: org member posts a rating + text review; it enters PENDING and only
 * PUBLISHED reviews are ever surfaced publicly. One active (PENDING/PUBLISHED)
 * review per user per org — a duplicate submission is rejected with 409 rather
 * than silently replacing the previous one.
 *
 * Moderate: SUPER_ADMIN (manage_system gate on the route) publishes/hides/
 * flags/responds; every moderation writes an audit log and notifies the
 * submitter (action → reaction).
 */
export class ReviewService {
    private readonly db: ReviewDb;

    constructor(db: ReviewDb = prisma as unknown as ReviewDb) {
        this.db = db;
    }

    async submit(input: SubmitReviewInput) {
        if (!Number.isInteger(input.rating) || input.rating < 1 || input.rating > 5) {
            throw new AppError('VALIDATION_ERROR', 'Rating must be an integer between 1 and 5.', 400);
        }
        const text = input.text.trim();
        if (text.length < REVIEW_TEXT_MIN || text.length > REVIEW_TEXT_MAX) {
            throw new AppError('VALIDATION_ERROR', `Review text must be between ${REVIEW_TEXT_MIN} and ${REVIEW_TEXT_MAX} characters.`, 400);
        }
        if (!input.orgId) {
            throw new AppError('ORG_REQUIRED', 'An organization is required to submit a review.', 400);
        }

        return this.db.$transaction(async (tx: any) => {
            const user = await tx.user.findUnique({
                where: { id: input.userId },
                select: { id: true, orgId: true, deletedAt: true, isDisabled: true },
            });
            if (!user || user.deletedAt || user.isDisabled) {
                throw new AppError('USER_NOT_FOUND', 'Review author is unavailable.', 404);
            }
            // Tenant isolation: the review is always about the author's own org —
            // a client-supplied orgId can never describe another company.
            if (user.orgId !== input.orgId) {
                throw new AppError('TENANT_DENIED', 'Reviews can only be submitted for your own company.', 403);
            }

            const existing = await tx.review.findFirst({
                where: { userId: input.userId, orgId: input.orgId, status: { in: ['PENDING', 'PUBLISHED'] } },
                select: { id: true, status: true },
            });
            if (existing) {
                throw new AppError(
                    'REVIEW_DUPLICATE',
                    existing.status === 'PENDING'
                        ? 'Your previous review is awaiting moderation.'
                        : 'You have already reviewed this company. Your review is published.',
                    409,
                );
            }

            const publicId = await allocateNextPublicId('PM-REV', 'Review');
            const review = await tx.review.create({
                data: {
                    publicId,
                    userId: input.userId,
                    orgId: input.orgId,
                    rating: input.rating,
                    text,
                    status: 'PENDING',
                },
            });

            await tx.auditLog.create({
                data: {
                    action: 'CREATE',
                    entityType: 'Review',
                    entityId: review.id,
                    targetId: review.id,
                    changes: { publicId, rating: input.rating, orgId: input.orgId, status: 'PENDING' },
                    userId: input.userId,
                    orgId: input.orgId,
                    requestId: input.requestId,
                    ipAddress: input.ipAddress,
                    userAgent: input.userAgent,
                },
            });

            return review;
        });
    }

    async listMine(userId: string, orgId: string) {
        return this.db.review.findMany({
            where: { userId, orgId },
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                publicId: true,
                rating: true,
                text: true,
                status: true,
                adminResponse: true,
                moderatedAt: true,
                createdAt: true,
            },
        });
    }

    /**
     * Public/published review list for a company. Only PUBLISHED reviews are
     * ever returned — moderation state is never leaked through this path.
     */
    async listPublished(orgId: string, page = 1, limit = 20) {
        const where = { orgId, status: 'PUBLISHED' as const };
        const [reviews, total] = await Promise.all([
            this.db.review.findMany({
                where,
                include: {
                    user: { select: { firstName: true, lastName: true, publicId: true } },
                },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
            }),
            this.db.review.count({ where }),
        ]);
        return { reviews, total, page, totalPages: Math.max(1, Math.ceil(total / limit)) };
    }

    async listForAdmin(filters: {
        status?: string;
        search?: string;
        orgId?: string;
        page?: number;
        limit?: number;
    }) {
        const page = filters.page ?? 1;
        const limit = filters.limit ?? 25;
        const where: Record<string, unknown> = {};

        if (filters.status && filters.status !== 'ALL') {
            where.status = filters.status;
        }
        if (filters.orgId) {
            where.orgId = filters.orgId;
        }
        if (filters.search && filters.search.trim().length > 0) {
            const q = filters.search.trim();
            where.OR = [
                { publicId: { contains: q, mode: 'insensitive' } },
                { text: { contains: q, mode: 'insensitive' } },
                { user: { firstName: { contains: q, mode: 'insensitive' } } },
                { user: { lastName: { contains: q, mode: 'insensitive' } } },
                { org: { name: { contains: q, mode: 'insensitive' } } },
                { org: { publicId: { contains: q, mode: 'insensitive' } } },
            ];
        }

        const [reviews, total, grouped] = await Promise.all([
            this.db.review.findMany({
                where,
                include: {
                    user: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true, role: true } },
                    org: { select: { id: true, publicId: true, name: true } },
                },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
            }),
            this.db.review.count({ where }),
            this.db.review.groupBy({
                by: ['status'],
                _count: { _all: true },
            }),
        ]);

        const statusCounts: Record<string, number> = {};
        for (const g of grouped as Array<{ status: string; _count: { _all: number } }>) {
            statusCounts[g.status] = g._count._all;
        }

        return {
            reviews,
            total,
            page,
            totalPages: Math.max(1, Math.ceil(total / limit)),
            summary: {
                total: Object.values(statusCounts).reduce((sum: number, n: number) => sum + n, 0),
                pendingCount: statusCounts.PENDING ?? 0,
                publishedCount: statusCounts.PUBLISHED ?? 0,
                hiddenCount: statusCounts.HIDDEN ?? 0,
                flaggedCount: statusCounts.FLAGGED ?? 0,
            },
        };
    }

    async getRatingSummary(): Promise<ReviewSummary> {
        const grouped = await this.db.review.groupBy({
            by: ['status'],
            _count: { _all: true },
        });
        const byStatus: Record<string, number> = {};
        for (const g of grouped as Array<{ status: string; _count: { _all: number } }>) {
            byStatus[g.status] = g._count._all;
        }

        const published = await this.db.review.findMany({
            where: { status: 'PUBLISHED' },
            select: { rating: true },
        });
        const distribution: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
        let sum = 0;
        for (const r of published) {
            distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
            sum += r.rating;
        }

        return {
            total: Object.values(byStatus).reduce((sum: number, n: number) => sum + n, 0),
            average: published.length > 0 ? Math.round((sum / published.length) * 10) / 10 : 0,
            distribution,
            pendingCount: byStatus.PENDING ?? 0,
            publishedCount: byStatus.PUBLISHED ?? 0,
            hiddenCount: byStatus.HIDDEN ?? 0,
            flaggedCount: byStatus.FLAGGED ?? 0,
        };
    }

    async getDetail(reviewId: string) {
        const review = await this.db.review.findUnique({
            where: { id: reviewId },
            include: {
                user: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true, role: true } },
                org: { select: { id: true, publicId: true, name: true } },
                moderatedBy: { select: { id: true, publicId: true, firstName: true, lastName: true } },
            },
        });
        if (!review) throw new AppError('REVIEW_NOT_FOUND', 'Review not found.', 404);
        return review;
    }

    async moderate(input: ModerateReviewInput) {
        const response = input.response?.trim();
        if (input.action === 'RESPOND') {
            if (!response) {
                throw new AppError('VALIDATION_ERROR', 'A response is required for the RESPOND action.', 400);
            }
            if (response.length > 2000) {
                throw new AppError('VALIDATION_ERROR', 'Response must be 2000 characters or fewer.', 400);
            }
        }

        return this.db.$transaction(async (tx: any) => {
            const review = await tx.review.findUnique({
                where: { id: input.reviewId },
                select: { id: true, publicId: true, userId: true, orgId: true, status: true, adminResponse: true, rating: true },
            });
            if (!review) throw new AppError('REVIEW_NOT_FOUND', 'Review not found.', 404);

            const isTransition = input.action !== 'RESPOND';
            const nextStatus = isTransition
                ? NEXT_STATUS[input.action as 'PUBLISH' | 'HIDE' | 'FLAG']
                : review.status;
            if (isTransition && review.status === nextStatus) {
                throw new AppError('REVIEW_STATE_CONFLICT', `Review is already ${nextStatus}.`, 409);
            }

            const moderatedAt = new Date();
            const updated = await tx.review.update({
                where: { id: review.id },
                data: {
                    status: nextStatus,
                    moderatedById: input.adminId,
                    moderatedAt,
                    ...(response ? { adminResponse: response } : {}),
                },
            });

            const title = input.action === 'PUBLISH'
                ? 'Your review has been published'
                : input.action === 'HIDE'
                    ? 'Your review has been hidden'
                    : input.action === 'FLAG'
                        ? 'Your review has been flagged'
                        : 'PayMuster responded to your review';
            await tx.notification.create({
                data: {
                    orgId: review.orgId,
                    userId: review.userId,
                    title,
                    body: input.action === 'PUBLISH'
                        ? 'Your company review is now published. Thank you for your feedback.'
                        : input.action === 'RESPOND' && response
                            ? response.slice(0, 300)
                            : 'Your company review has been moderated by the PayMuster team.',
                    type: 'REVIEW_MODERATION',
                    deepLink: null,
                },
            });

            await tx.auditLog.create({
                data: {
                    action: 'UPDATE',
                    entityType: 'Review',
                    entityId: review.id,
                    targetId: review.id,
                    changes: {
                        action: input.action,
                        previousStatus: review.status,
                        status: nextStatus,
                        publicId: review.publicId,
                        response: response ?? null,
                    },
                    userId: input.adminId,
                    orgId: review.orgId,
                    requestId: input.requestId,
                    ipAddress: input.ipAddress,
                    userAgent: input.userAgent,
                },
            });

            return updated;
        });
    }
}

export const reviewService = new ReviewService();
