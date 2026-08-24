import { Router } from 'express';
import { getMailUsage, previewMail, sendMail, getMailHistory } from '../controllers/mail-supply.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';

const router = Router();

router.use(requireAuth);

// GET /api/v1/mail-supply/usage — current month's usage and quota
router.get('/usage', auditMiddleware, getMailUsage);

// POST /api/v1/mail-supply/preview — preview targets before sending
router.post('/preview', auditMiddleware, previewMail);

// POST /api/v1/mail-supply/send — send mail with quota enforcement
router.post('/send', auditMiddleware, sendMail);

// GET /api/v1/mail-supply/history — sent mail history
router.get('/history', auditMiddleware, getMailHistory);

export default router;
