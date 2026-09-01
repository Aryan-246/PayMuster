import { Router } from 'express';
import { adminController } from '../controllers/admin.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateRequest } from '../middlewares/validation.middleware.js';
import { dispatchAnnouncementSchema } from '../schemas/announcement.schema.js';
import { adminAiChatSchema } from '../schemas/admin-ai.schema.js';
import { adminReviewModerateSchema, adminReviewParamsSchema } from '../schemas/review.schema.js';
import { rateLimit } from '../lib/rate-limit.js';
import {
    adminDocumentParamsSchema,
    adminDocumentRejectSchema,
    adminDocumentVerifyBodySchema,
} from '../schemas/document.schema.js';

const router = Router();
const providerHealthRateLimit = rateLimit(60_000, 30, {
    keyPrefix: 'admin-provider-health',
    keyGenerator: (request) => request.context?.user?.id ?? request.ip ?? 'unknown',
});

router.use(requireAuth);
router.use(requirePermission('manage_system'));

router.get('/providers/health', providerHealthRateLimit, adminController.getProviderHealth.bind(adminController));
router.get('/search', auditMiddleware, adminController.searchFoundation.bind(adminController));
router.get('/dashboard', auditMiddleware, adminController.getDashboard.bind(adminController));

router.get('/users', auditMiddleware, adminController.searchUsers.bind(adminController));
router.get('/users/:id', auditMiddleware, adminController.getUserById.bind(adminController));
router.post('/users/:id/action', auditMiddleware, adminController.userAction.bind(adminController));
router.post('/users/:id/reset-password', auditMiddleware, adminController.resetPassword.bind(adminController));

router.get('/owner-requests', auditMiddleware, adminController.getOwnerRequests.bind(adminController));
router.post('/owner-requests/:id/approve', auditMiddleware, adminController.approveOwnerRequest.bind(adminController));
router.post('/owner-requests/:id/reject', auditMiddleware, adminController.rejectOwnerRequest.bind(adminController));

router.get('/companies', auditMiddleware, adminController.getCompanies.bind(adminController));
router.get('/companies/:id', auditMiddleware, adminController.getCompanyDetail.bind(adminController));

router.get('/sites', auditMiddleware, adminController.getSites.bind(adminController));
router.get('/sites/:id', auditMiddleware, adminController.getSiteDetail.bind(adminController));
router.get('/attendance', auditMiddleware, adminController.getAttendanceRecords.bind(adminController));
router.get('/attendance/:id', auditMiddleware, adminController.getAttendanceDetail.bind(adminController));
router.get('/payroll', auditMiddleware, adminController.getPayrollRecords.bind(adminController));
router.get('/payroll/:id', auditMiddleware, adminController.getPayrollDetail.bind(adminController));

router.get('/audit-logs', auditMiddleware, adminController.getAuditLogs.bind(adminController));
router.get('/notifications', auditMiddleware, adminController.getNotifications.bind(adminController));
router.post(
    '/announcements',
    validateRequest(dispatchAnnouncementSchema),
    auditMiddleware,
    adminController.dispatchAnnouncement.bind(adminController),
);

router.get('/maintenance', auditMiddleware, adminController.getMaintenance.bind(adminController));
router.post('/maintenance/enable', auditMiddleware, adminController.enableMaintenance.bind(adminController));
router.post('/maintenance/disable', auditMiddleware, adminController.disableMaintenance.bind(adminController));

// Customer Reviews administration (SUPER_ADMIN via the manage_system gate).
router.get('/reviews', auditMiddleware, adminController.listReviews.bind(adminController));
router.get('/reviews/summary', auditMiddleware, adminController.getReviewSummary.bind(adminController));
router.get('/reviews/:id', auditMiddleware, adminController.getReviewDetail.bind(adminController));
router.post(
    '/reviews/:id/moderate',
    validateParams(adminReviewParamsSchema),
    validateRequest(adminReviewModerateSchema),
    auditMiddleware,
    adminController.moderateReview.bind(adminController),
);

// Subscription administration (SUPER_ADMIN via the manage_system gate above).
router.get('/subscription/switch', auditMiddleware, adminController.getSubscriptionSwitch.bind(adminController));
router.post('/subscription/switch', auditMiddleware, adminController.setSubscriptionSwitch.bind(adminController));
router.post('/subscription/reconcile', auditMiddleware, adminController.reconcileSubscriptions.bind(adminController));
router.post('/subscription/orgs/:orgId/unlimited', auditMiddleware, adminController.grantUnlimitedAccess.bind(adminController));
router.delete('/subscription/orgs/:orgId/unlimited', auditMiddleware, adminController.revokeUnlimitedAccess.bind(adminController));

// Subscriptions platform view: subscriber list, detail, plans, offers.
router.get('/subscriptions', auditMiddleware, adminController.listSubscriptions.bind(adminController));
router.get('/subscriptions/plans', auditMiddleware, adminController.listPlans.bind(adminController));
router.get('/subscriptions/orgs/:orgId', auditMiddleware, adminController.getSubscriptionDetail.bind(adminController));
router.post('/subscriptions/orgs/:orgId/offers', auditMiddleware, adminController.grantOffer.bind(adminController));
router.delete('/subscriptions/orgs/:orgId/offers/:key', auditMiddleware, adminController.revokeOffer.bind(adminController));

// Platform payments.
router.get('/payments', auditMiddleware, adminController.listPayments.bind(adminController));
router.get('/payments/:id', auditMiddleware, adminController.getPaymentDetail.bind(adminController));

// Platform mail supply: overview + composer (preview/send reuse the mail-supply
// service delivery core; audience resolution + quota enforcement are server-side).
router.get('/mail/overview', auditMiddleware, adminController.getMailOverview.bind(adminController));
router.post('/mail/preview', auditMiddleware, adminController.previewPlatformMail.bind(adminController));
router.post('/mail/send', auditMiddleware, adminController.sendPlatformMail.bind(adminController));

// Platform announcements: single compose workflow (validated dispatch +
// real recipient-count preview) and history.
router.get('/announcements', auditMiddleware, adminController.listAnnouncementsAdmin.bind(adminController));
router.post(
    '/announcements/preview',
    validateRequest(dispatchAnnouncementSchema),
    auditMiddleware,
    adminController.previewAnnouncement.bind(adminController),
);

// Reports / analytics (real 30-day aggregations).
router.get('/reports/overview', auditMiddleware, adminController.getReportsOverview.bind(adminController));

router.post(
    '/ai/chat',
    validateRequest(adminAiChatSchema),
    auditMiddleware,
    adminController.aiChat.bind(adminController),
);

router.get('/documents/pending', auditMiddleware, adminController.getPendingDocuments.bind(adminController));
router.post(
    '/documents/:id/claim',
    validateParams(adminDocumentParamsSchema),
    auditMiddleware,
    adminController.claimDocument.bind(adminController),
);
router.post(
    '/documents/:id/view',
    validateParams(adminDocumentParamsSchema),
    auditMiddleware,
    adminController.createDocumentViewUrl.bind(adminController),
);
router.post(
    '/documents/:id/verify',
    validateParams(adminDocumentParamsSchema),
    validateRequest(adminDocumentVerifyBodySchema),
    auditMiddleware,
    adminController.verifyDocument.bind(adminController),
);
router.post(
    '/documents/:id/reject',
    validateParams(adminDocumentParamsSchema),
    validateRequest(adminDocumentRejectSchema),
    auditMiddleware,
    adminController.rejectDocument.bind(adminController),
);

export default router;
