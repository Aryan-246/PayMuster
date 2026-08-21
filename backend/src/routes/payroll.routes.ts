import { Router } from 'express';
import { payrollController } from '../controllers/payroll.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateQuery, validateRequest } from '../middlewares/validation.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { createPayrollSchema, listPayrollQuerySchema } from '../schemas/payroll.schema.js';

const router = Router();

router.use(requireAuth);

router.get('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_payroll'),
  validateQuery(listPayrollQuerySchema),
  auditMiddleware,
  payrollController.listPayroll.bind(payrollController)
);

router.post('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('run_payroll'),
  validateRequest(createPayrollSchema),
  auditMiddleware,
  payrollController.createPayroll.bind(payrollController)
);

router.get('/:id',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_payroll'),
  auditMiddleware,
  payrollController.getPayroll.bind(payrollController)
);

export default router;
