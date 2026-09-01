import { Router } from 'express';

import { announcementController } from '../controllers/announcement.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateQuery, validateRequest } from '../middlewares/validation.middleware.js';
import {
    acknowledgeAnnouncementParamsSchema,
    listAnnouncementsQuerySchema,
    tenantDispatchAnnouncementSchema,
} from '../schemas/announcement.schema.js';

const router = Router();

router.use(requireAuth);

// POST /api/v1/announcements/dispatch — org-scoped dispatch for OWNER/ADMIN
// (blueprint C2). orgId is forced server-side to the actor's org.
router.post(
    '/dispatch',
    requireTenant({ scope: 'COMPANY' }),
    requirePermission('manage_announcements'),
    validateRequest(tenantDispatchAnnouncementSchema),
    auditMiddleware,
    announcementController.dispatchOrgScoped.bind(announcementController),
);

router.get(
    '/',
    validateQuery(listAnnouncementsQuerySchema),
    auditMiddleware,
    announcementController.listMine.bind(announcementController),
);
router.get(
    '/stream',
    announcementController.streamMine.bind(announcementController),
);
router.post(
    '/:id/acknowledge',
    validateParams(acknowledgeAnnouncementParamsSchema),
    auditMiddleware,
    announcementController.acknowledge.bind(announcementController),
);

export default router;
