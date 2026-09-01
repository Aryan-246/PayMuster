import type { Request, Response } from 'express';

import { reviewService } from '../services/review.service.js';
import { AppError } from '../lib/app-error.js';

/**
 * Review Controller — member-side review endpoints.
 *
 * Authorization: requireAuth + requireTenant(COMPANY) on the routes; the org is
 * resolved server-side from the authenticated user (never the client body),
 * and the service re-checks user.orgId === orgId before creating anything.
 */
export class ReviewController {
    async submit(req: Request, res: Response) {
        const user = req.context?.user;
        if (!user) {
            throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
        }
        const orgId = req.context?.tenant?.companyId;
        if (!orgId) {
            throw new AppError('TENANT_REQUIRED', 'An organization context is required.', 400);
        }

        const review = await reviewService.submit({
            userId: user.id,
            orgId,
            rating: req.body.rating,
            text: req.body.text,
            requestId: req.id,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
        });

        res.status(201).json({
            success: true,
            data: {
                id: review.id,
                publicId: review.publicId,
                rating: review.rating,
                status: review.status,
                createdAt: review.createdAt,
            },
            meta: { requestId: req.id },
        });
    }

    async listMine(req: Request, res: Response) {
        const user = req.context?.user;
        if (!user) {
            throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
        }
        const orgId = req.context?.tenant?.companyId;
        if (!orgId) {
            throw new AppError('TENANT_REQUIRED', 'An organization context is required.', 400);
        }
        const reviews = await reviewService.listMine(user.id, orgId);
        res.status(200).json({ success: true, data: reviews, meta: { requestId: req.id } });
    }
}

export const reviewController = new ReviewController();
