import { Router } from 'express';
import { financialController } from '../controllers/financial.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateQuery, validateRequest } from '../middlewares/validation.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import {
  createAllocationSchema,
  appendExpenseApprovalSchema,
  attachEvidenceSchema,
  listPaymentsQuerySchema,
  listExpensesQuerySchema,
} from '../schemas/financial.schema.js';

const router = Router();

router.use(requireAuth);

// Payment history for the Owner finance view (read path, view_payroll).
router.get('/payments',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_payroll'),
  validateQuery(listPaymentsQuerySchema),
  auditMiddleware,
  financialController.listPayments.bind(financialController)
);

// Expense ledger for the Owner finance view (read path, view_payroll).
router.get('/expenses',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_payroll'),
  validateQuery(listExpensesQuerySchema),
  auditMiddleware,
  financialController.listExpenses.bind(financialController)
);

// Payment / expense / pay-run divide: split an amount across a site or the company.
// Gated by run_payroll (SUPER_ADMIN, OWNER, ADMIN, ACCOUNTANT) — the finance-write cohort.
router.post('/allocations',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('run_payroll'),
  validateRequest(createAllocationSchema),
  auditMiddleware,
  financialController.createAllocation.bind(financialController)
);

// Append-only expense approval action (SUBMITTED / APPROVED / REJECTED).
router.post('/expense-approvals',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('run_payroll'),
  validateRequest(appendExpenseApprovalSchema),
  auditMiddleware,
  financialController.appendExpenseApproval.bind(financialController)
);

// Attach stored evidence (receipt/proof) to a financial source by content hash.
router.post('/evidence',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('run_payroll'),
  validateRequest(attachEvidenceSchema),
  auditMiddleware,
  financialController.attachEvidence.bind(financialController)
);

export default router;
