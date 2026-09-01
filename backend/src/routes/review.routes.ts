import { Router } from 'express';
import { z } from 'zod';

import { reviewController } from '../controllers/review.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateRequest } from '../middlewares/validation.middleware.js';

const router = Router();

export const submitReviewSchema = z
    .object({
        rating: z.number().int().min(1).max(5),
        text: z.string().trim().min(5).max(2000),
    })
    .strict();

router.use(requireAuth);

// POST /api/v1/reviews — a member submits a review of their own company.
// orgId is never taken from the client: requireTenant resolves it from the
// authenticated context and the service re-checks user.orgId === orgId.
router.post(
    '/',
    requireTenant({ scope: 'COMPANY' }),
    validateRequest(submitReviewSchema),
    auditMiddleware,
    reviewController.submit.bind(reviewController),
);

// GET /api/v1/reviews/mine — the author's own reviews (any status) for their org.
router.get(
    '/mine',
    requireTenant({ scope: 'COMPANY' }),
    auditMiddleware,
    reviewController.listMine.bind(reviewController),
);

export default router;
