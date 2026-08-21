import { Router } from 'express';
import { adminController } from '../controllers/admin.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { auditMiddleware } from '../middlewares/audit.middleware.js';
import { validateParams, validateRequest } from '../middlewares/validation.middleware.js';
import { dispatchAnnouncementSchema } from '../schemas/announcement.schema.js';
import { adminAiChatSchema } from '../schemas/admin-ai.schema.js';
import {
    adminDocumentParamsSchema,
    adminDocumentRejectSchema,
    adminDocumentVerifyBodySchema,
} from '../schemas/document.schema.js';

const router = Router();

router.use(requireAuth);
router.use(requirePermission('manage_system'));

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
