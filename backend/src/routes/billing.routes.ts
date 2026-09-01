import { Router } from 'express';

import { billingController } from '../controllers/billing.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { verifyCheckoutSchema } from '../schemas/billing.schema.js';

const router = Router();

router.post('/webhook/razorpay', billingController.receiveWebhook.bind(billingController));

router.use(requireAuth);
router.get(
    '/summary',
    requireTenant({ scope: 'COMPANY' }),
    requirePermission('manage_billing'),
    billingController.getSummary.bind(billingController),
);

router.post(
    '/checkout/order',
    requireTenant({ scope: 'COMPANY' }),
    requirePermission('manage_billing'),
    auditMiddleware,
    billingController.createCheckoutOrder.bind(billingController),
);

router.post(
    '/checkout/verify',
    requireTenant({ scope: 'COMPANY' }),
    requirePermission('manage_billing'),
    validateRequest(verifyCheckoutSchema),
    auditMiddleware,
    billingController.verifyCheckout.bind(billingController),
);

export default router;
