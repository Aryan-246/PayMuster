import { Router } from 'express';
import { companyController } from '../controllers/company.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requireTenant } from '../middlewares/tenant.middleware.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import {
  updateCompanySettingsSchema,
  joinRequestSchema,
  rejectRequestSchema,
  promotionRequestSchema,
  ownerRequestSchema,
  inviteUserSchema,
  acceptInvitationSchema
} from '../schemas/company.schema.js';

const router = Router();

// PUBLIC LOOKUP
router.get('/lookup', companyController.lookupCompany.bind(companyController));

// Apply auth to all
router.use(requireAuth);

// OVERVIEW & SETTINGS
router.get('/',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('view_reports'),
  auditMiddleware,
  companyController.getOverview.bind(companyController)
);

router.patch('/settings',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_settings'),
  validateRequest(updateCompanySettingsSchema),
  auditMiddleware,
  companyController.updateSettings.bind(companyController)
);

// JOIN REQUESTS
router.get('/join',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.getJoinRequests.bind(companyController)
);

router.post('/join',
  requireTenant({ scope: 'COMPANY', allowUnaffiliatedCompany: true }),
  validateRequest(joinRequestSchema),
  auditMiddleware,
  companyController.requestJoin.bind(companyController)
);

router.post('/join/:id/approve',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.approveJoin.bind(companyController)
);

router.post('/join/:id/reject',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  validateRequest(rejectRequestSchema),
  auditMiddleware,
  companyController.rejectJoin.bind(companyController)
);

// PROMOTION REQUESTS
router.post('/promotion',
  requireTenant({ scope: 'COMPANY' }),
  validateRequest(promotionRequestSchema),
  auditMiddleware,
  companyController.requestPromotion.bind(companyController)
);

router.post('/promotion/:id/approve',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.approvePromotion.bind(companyController)
);

// OWNER REQUESTS
router.post('/owner-request',
  validateRequest(ownerRequestSchema),
  auditMiddleware,
  companyController.requestOwnership.bind(companyController)
);

router.get('/owner-request/my',
  companyController.getMyOwnershipRequest.bind(companyController)
);

// INVITATIONS
router.post('/invitation',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  validateRequest(inviteUserSchema),
  auditMiddleware,
  companyController.inviteUser.bind(companyController)
);

router.post('/invitation/accept',
  validateRequest(acceptInvitationSchema),
  auditMiddleware,
  companyController.acceptInvitation.bind(companyController)
);

// STAFF LIFECYCLE
router.post('/staff/:id/change-role',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.changeRole.bind(companyController)
);

router.post('/staff/:id/suspend',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.suspendStaff.bind(companyController)
);

router.post('/staff/:id/restore',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.restoreStaff.bind(companyController)
);

router.post('/staff/:id/terminate',
  requireTenant({ scope: 'COMPANY' }),
  requirePermission('manage_staff'),
  auditMiddleware,
  companyController.terminateStaff.bind(companyController)
);

export default router;
