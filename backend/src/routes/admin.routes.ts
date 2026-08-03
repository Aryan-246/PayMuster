import { Router } from 'express';
import { adminController } from '../controllers/admin.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';

const router = Router();

router.use(requireAuth);

router.get('/users',
  
  requirePermission('manage_system'),
  auditMiddleware,
  adminController.searchUsers.bind(adminController)
);

router.post('/users/:id/action',
  
  requirePermission('manage_system'),
  auditMiddleware,
  adminController.userAction.bind(adminController)
);

export default router;
