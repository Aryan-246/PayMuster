import { Router } from 'express';
import { getMailUsage, previewMail, sendMail, getMailHistory } from '../controllers/mail-supply.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';

const router = Router();

// Central RBAC spine: auth → tenant (server-authoritative orgId) → manage_mail.
// SUPER_ADMIN (org-less platform operator) may call without a company header.
const mailGuard = [
    requireAuth,
    requireTenant({ scope: 'COMPANY', allowUnaffiliatedCompany: true }),
    requirePermission('manage_mail'),
];

// GET /api/v1/mail-supply/usage — current month's usage and quota
router.get('/usage', ...mailGuard, auditMiddleware, getMailUsage);

// POST /api/v1/mail-supply/preview — preview targets before sending
router.post('/preview', ...mailGuard, auditMiddleware, previewMail);

// POST /api/v1/mail-supply/send — send mail with quota enforcement
router.post('/send', ...mailGuard, auditMiddleware, sendMail);

// GET /api/v1/mail-supply/history — sent mail history
router.get('/history', ...mailGuard, auditMiddleware, getMailHistory);

export default router;
