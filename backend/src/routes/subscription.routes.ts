import { Router } from 'express';
import { getSubscriptionState } from '../controllers/subscription-state.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';

const router = Router();

// GET /api/v1/subscription/state — read-only, honest subscription/entitlement view
// for the tenant UI (blueprint §F / §I). Any authenticated member of the org.
router.get('/state', requireAuth, requireTenant({ scope: 'COMPANY' }), auditMiddleware, getSubscriptionState);

export default router;
