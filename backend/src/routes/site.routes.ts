import { Router } from 'express';
import { siteController } from '../controllers/site.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { createSiteSchema, updateSiteStatusSchema } from '../schemas/site.schema.js';

const router = Router();

// Apply auth to all routes
router.use(requireAuth);

// GET /api/v1/sites - Get all sites for the company (requires companyId in headers)
router.get('/', 
  requireTenant({ scope: 'COMPANY' }), 
  requirePermission('view_sites'), 
  auditMiddleware,
  siteController.getSites.bind(siteController)
);

// POST /api/v1/sites - Create a new site
router.post('/', 
  requireTenant({ scope: 'COMPANY' }), 
  requirePermission('manage_site'), 
  validateRequest(createSiteSchema),
  auditMiddleware,
  siteController.createSite.bind(siteController)
);

// GET /api/v1/sites/:siteId - Get specific site
router.get('/:siteId', 
  requireTenant({ scope: 'SITE' }), 
  requirePermission('view_site_details'), 
  auditMiddleware,
  siteController.getSiteDetails.bind(siteController)
);

// PATCH /api/v1/sites/:siteId/status - Update site status
router.patch('/:siteId/status', 
  requireTenant({ scope: 'SITE' }), 
  requirePermission('manage_site'), 
  validateRequest(updateSiteStatusSchema),
  auditMiddleware,
  siteController.updateStatus.bind(siteController)
);

// POST /api/v1/sites/:siteId/members - Add member to site
router.post('/:siteId/members', 
  requireTenant({ scope: 'SITE' }), 
  requirePermission('manage_staff'), 
  auditMiddleware,
  siteController.assignWorker.bind(siteController)
);

export default router;
