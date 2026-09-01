import { Router } from 'express';
import { staffController } from '../controllers/staff.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateQuery, validateRequest } from '../middlewares/validation.middleware.js';
import {
  createStaffSchema,
  listStaffDocumentsQuerySchema,
  reviewStaffDocumentParamsSchema,
  reviewStaffDocumentSchema,
} from '../schemas/staff.schema.js';

const router = Router();

// Apply auth to all staff-directory routes.
router.use(requireAuth);

// Read the worker roster for the caller's organization.
router.get('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_staff'),
  auditMiddleware,
  staffController.listStaff.bind(staffController)
);

// Manual worker add — OWNER/ADMIN (manage_staff).
router.post('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  validateRequest(createStaffSchema),
  auditMiddleware,
  staffController.createStaff.bind(staffController)
);

// Read a single worker record (tenant-scoped).
router.get('/:id',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_staff'),
  auditMiddleware,
  staffController.getStaffById.bind(staffController)
);

// Enriched Owner/ADMIN staff profile: salary rules, payments, bank readiness,
// documents, verification state. manage_staff-gated so the financial PII slice
// never reaches the view_staff roster audience.
router.get('/:id/profile',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  staffController.getStaffProfile.bind(staffController)
);

// Document review queue for one worker (metadata only; bytes via signed URL).
router.get('/:id/documents',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_documents'),
  validateQuery(listStaffDocumentsQuerySchema),
  auditMiddleware,
  staffController.listStaffDocuments.bind(staffController)
);

// Approve / reject / verify a worker document (owner blue-tick flow).
router.post('/:id/documents/:documentId/review',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_documents'),
  validateParams(reviewStaffDocumentParamsSchema),
  validateRequest(reviewStaffDocumentSchema),
  auditMiddleware,
  staffController.reviewStaffDocument.bind(staffController)
);

export default router;
