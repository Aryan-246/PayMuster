import { Router } from 'express';

import { announcementController } from '../controllers/announcement.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateQuery } from '../middlewares/validation.middleware.js';
import {
    acknowledgeAnnouncementParamsSchema,
    listAnnouncementsQuerySchema,
} from '../schemas/announcement.schema.js';

const router = Router();

router.use(requireAuth);

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
