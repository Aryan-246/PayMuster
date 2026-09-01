import { Router } from 'express';
import { createRealtimeToken } from '../controllers/realtime.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';

const router = Router();

// POST /api/v1/realtime/token — Stream server token mint for the actor's org
// channel (blueprint §F/C5). Authenticated org members holding use_realtime.
router.post(
    '/token',
    requireAuth,
    requireTenant({ scope: 'COMPANY' }),
    requirePermission('use_realtime'),
    auditMiddleware,
    createRealtimeToken,
);

export default router;
