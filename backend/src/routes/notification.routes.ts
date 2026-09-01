import { Router } from 'express';
import { notificationController } from '../controllers/notification.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateQuery } from '../middlewares/validation.middleware.js';
import {
    listNotificationsQuerySchema,
    markNotificationReadParamsSchema,
} from '../schemas/notification.schema.js';

const router = Router();

router.use(requireAuth);

// GET /api/v1/notifications — the caller's notification center (paginated,
// with an unread badge count). Scoped server-side to the actor's user + org.
router.get(
    '/',
    requireTenant({ scope: 'COMPANY' }),
    validateQuery(listNotificationsQuerySchema),
    auditMiddleware,
    notificationController.listMine.bind(notificationController),
);

// POST /api/v1/notifications/:id/read — mark one notification read (idempotent).
router.post(
    '/:id/read',
    requireTenant({ scope: 'COMPANY' }),
    validateParams(markNotificationReadParamsSchema),
    auditMiddleware,
    notificationController.markRead.bind(notificationController),
);

// POST /api/v1/notifications/read-all — mark every unread notification read.
router.post(
    '/read-all',
    requireTenant({ scope: 'COMPANY' }),
    auditMiddleware,
    notificationController.markAllRead.bind(notificationController),
);

export default router;
