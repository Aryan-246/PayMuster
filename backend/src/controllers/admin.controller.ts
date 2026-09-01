import { Request, Response } from 'express';
import { AppError } from '../lib/app-error.js';
import { adminService } from '../services/admin.service.js';
import { adminSubscriptionService } from '../services/admin-subscription.service.js';
import { adminOpsService } from '../services/admin-ops.service.js';
import { reviewService } from '../services/review.service.js';
import { mailSupplyService } from '../services/mail-supply.service.js';
import { announcementService } from '../services/announcement.service.js';
import { announcementInvalidationBroker } from '../lib/announcement-invalidation.js';
import { maintenanceService } from '../lib/maintenance-service.js';
import { aiService } from '../services/ai.service.js';
import { providerHealth, redactProviderConfiguration } from '../providers/registry.js';
import { searchService } from '../providers/search.service.js';
import { subscriptionService } from '../services/subscription.service.js';

function requireActor(req: Request) {
  const actor = req.context?.user;
  if (!actor) {
    throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
  }
  return actor;
}

export class AdminController {
  async searchFoundation(req: Request, res: Response) {
    const actor = req.context.user;
    if (!actor) {
      throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
    }
    const result = await searchService.search({
      query: typeof req.query.q === 'string' ? req.query.q : '',
      page: Math.max(1, Number(req.query.page ?? 1)),
      limit: Math.min(100, Math.max(1, Number(req.query.limit ?? 25))),
      filters: {
        role: typeof req.query.role === 'string' ? req.query.role : undefined,
        status: typeof req.query.status === 'string' ? req.query.status : undefined,
      },
      context: {
        userId: actor.id,
        role: actor.role,
        orgId: actor.orgId,
        permissions: ['manage_system'],
      },
    });
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async getProviderHealth(req: Request, res: Response) {
    const providers = await providerHealth();
    res.status(200).json({
      success: true,
      data: {
        providers,
        configuration: redactProviderConfiguration(),
        freeOnly: true,
      },
      meta: { requestId: req.id },
    });
  }

  async getDashboard(req: Request, res: Response) {
    const counts = await adminService.getDashboardCounts();
    res.status(200).json({ success: true, data: counts, meta: { requestId: req.id } });
  }

  async searchUsers(req: Request, res: Response) {
    const query = (req.query.q || req.query.query || req.query.search) as string | undefined;
    const role = req.query.role as string | undefined;
    const status = req.query.status as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);

    const result = await adminService.searchUsers(query, role, status, page, limit);
    res.status(200).json({
      success: true,
      data: result.users,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages }
    });
  }

  async getUserById(req: Request, res: Response) {
    const userId = req.params.id as string;
    const data = await adminService.getUserById(userId);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async getOwnerRequests(req: Request, res: Response) {
    const status = req.query.status as string | undefined;
    const requests = await adminService.getOwnerRequests(status);
    res.status(200).json({ success: true, data: requests, meta: { requestId: req.id } });
  }

  async approveOwnerRequest(req: Request, res: Response) {
    const requestId = req.params.id as string;
    const approvedBy = req.context.user!.id;
    const result = await adminService.approveOwnerRequest(requestId, approvedBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async rejectOwnerRequest(req: Request, res: Response) {
    const requestId = req.params.id as string;
    const rejectedBy = req.context.user!.id;
    const reason = req.body?.reason as string | undefined;
    const result = await adminService.rejectOwnerRequest(requestId, rejectedBy, reason);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async getCompanies(req: Request, res: Response) {
    const search = req.query.search as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getCompanies(search, page, limit);
    res.status(200).json({
      success: true,
      data: result.companies,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages }
    });
  }

  async getCompanyDetail(req: Request, res: Response) {
    const orgId = req.params.id as string;
    const data = await adminService.getCompanyDetail(orgId);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async getSites(req: Request, res: Response) {
    const search = req.query.search as string | undefined;
    const orgId = req.query.orgId as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getSites(search, orgId, page, limit);
    res.status(200).json({
      success: true,
      data: result.sites,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages }
    });
  }

  async getAttendanceRecords(req: Request, res: Response) {
    const search = req.query.search as string | undefined;
    const orgId = req.query.orgId as string | undefined;
    const siteId = req.query.siteId as string | undefined;
    const status = req.query.status as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getAttendanceRecords(search, orgId, siteId, status, page, limit);
    res.status(200).json({
      success: true,
      data: result.records,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        summary: result.summary,
      }
    });
  }

  async getAttendanceDetail(req: Request, res: Response) {
    const id = req.params.id as string;
    const orgId = req.query.orgId as string | undefined;
    const siteId = req.query.siteId as string | undefined;
    const record = await adminService.getAttendanceDetail(id, orgId, siteId);
    res.status(200).json({ success: true, data: record, meta: { requestId: req.id } });
  }

  async getPayrollRecords(req: Request, res: Response) {
    const orgId = req.query.orgId as string | undefined;
    const status = req.query.status as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getPayrollRecords(orgId, status, page, limit);
    res.status(200).json({
      success: true,
      data: result.payRuns,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        summary: result.summary,
      }
    });
  }

  async getPayrollDetail(req: Request, res: Response) {
    const id = req.params.id as string;
    const orgId = req.query.orgId as string | undefined;
    const record = await adminService.getPayrollDetail(id, orgId);
    res.status(200).json({ success: true, data: record, meta: { requestId: req.id } });
  }

  async getAuditLogs(req: Request, res: Response) {
    const entityType = req.query.entityType as string | undefined;
    const action = req.query.action as string | undefined;
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getAuditLogs(entityType, action, page, limit);
    res.status(200).json({
      success: true,
      data: result.auditLogs,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages }
    });
  }

  async getNotifications(req: Request, res: Response) {
    const page = parseInt(req.query.page as string || '1', 10);
    const limit = parseInt(req.query.limit as string || '50', 10);
    const result = await adminService.getNotifications(page, limit);
    res.status(200).json({
      success: true,
      data: result.notifications,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages }
    });
  }

  async dispatchAnnouncement(req: Request, res: Response) {
    const actorId = req.context.user!.id;
    const result = await announcementService.dispatch(actorId, req.body, {
      requestId: req.id,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
    });

    announcementInvalidationBroker.publish(result.recipientIds, {
      reason: 'DISPATCHED',
      occurredAt: result.createdAt.toISOString(),
    });

    res.status(201).json({
      success: true,
      data: {
        campaignId: result.campaignId,
        audience: result.audience,
        orgId: result.orgId,
        recipientCount: result.recipientCount,
        createdAt: result.createdAt,
      },
      meta: { requestId: req.id },
    });
  }

  /** Real recipient-count preview for the single announcement compose workflow. */
  async previewAnnouncement(req: Request, res: Response) {
    const actor = req.context.user!;
    const result = await announcementService.preview(req.body, {
      role: actor.role,
      orgId: actor.orgId ?? null,
    });
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async getSiteDetail(req: Request, res: Response) {
    const data = await adminService.getSiteDetail(req.params.id as string);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async userAction(req: Request, res: Response) {
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const { action, role, reason } = req.body;

    const result = await adminService.executeAction(
      targetUserId,
      actionBy,
      action,
      role,
      {
        reason,
        requestId: req.id,
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      },
    );
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async resetPassword(req: Request, res: Response) {
    const targetUserId = req.params.id as string;
    const actionBy = req.context?.user?.id;
    if (!actionBy) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const result = await adminService.resetPassword(targetUserId, actionBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async getMaintenance(req: Request, res: Response) {
    const enabled = await maintenanceService.getIsMaintenanceMode();
    res.status(200).json({ success: true, data: { enabled }, meta: { requestId: req.id } });
  }

  async enableMaintenance(req: Request, res: Response) {
    const userId = req.context?.user?.id;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    await maintenanceService.setMaintenanceMode(true, userId);
    res.status(200).json({ success: true, message: 'Maintenance mode enabled', meta: { requestId: req.id } });
  }

  async disableMaintenance(req: Request, res: Response) {
    const userId = req.context?.user?.id;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    await maintenanceService.setMaintenanceMode(false, userId);
    res.status(200).json({ success: true, message: 'Maintenance mode disabled', meta: { requestId: req.id } });
  }

  async aiChat(req: Request, res: Response) {
    const actor = req.context?.user;
    if (!actor) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' },
      });
      return;
    }

    const result = await aiService.processChat({
      prompt: req.body.prompt,
      actorId: actor.id,
      role: actor.role,
      orgId: actor.orgId,
      requestId: req.id,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
      confirmationToken: typeof req.body.confirmationToken === 'string' ? req.body.confirmationToken : undefined,
    });

    res.status(200).json({
      success: true,
      data: result,
      meta: { requestId: req.id },
    });
  }

  async getPendingDocuments(req: Request, res: Response) {
    const result = await adminService.getPendingDocuments();
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async claimDocument(req: Request, res: Response) {
    const documentId = req.params.id as string;
    const adminId = req.context?.user?.id;
    if (!adminId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const result = await adminService.claimDocument(documentId, adminId);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async createDocumentViewUrl(req: Request, res: Response) {
    const result = await adminService.createDocumentViewUrl(req.params.id as string);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async verifyDocument(req: Request, res: Response) {
    const documentId = req.params.id as string;
    const adminId = req.context?.user?.id;
    if (!adminId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const result = await adminService.verifyDocument(documentId, adminId);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async rejectDocument(req: Request, res: Response) {
    const documentId = req.params.id as string;
    const reason = req.body?.reason as string | undefined;
    const adminId = req.context?.user?.id;
    if (!adminId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const result = await adminService.rejectDocument(documentId, adminId, reason);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // --- Subscription administration ---------------------------------------
  // Reachable only through the manage_system gate (SUPER_ADMIN); each service
  // call re-checks the actor role as defense in depth.

  async getSubscriptionSwitch(req: Request, res: Response) {
    const enabled = await subscriptionService.getGlobalSubscriptionSwitch();
    res.status(200).json({ success: true, data: { enabled }, meta: { requestId: req.id } });
  }

  async setSubscriptionSwitch(req: Request, res: Response) {
    const actor = req.context?.user;
    if (!actor) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    if (typeof req.body?.enabled !== 'boolean') {
      throw new AppError('VALIDATION_ERROR', 'A boolean "enabled" field is required.', 400);
    }
    const enabled = await subscriptionService.setGlobalSubscriptionSwitch(req.body.enabled, actor.id, actor.role);
    res.status(200).json({ success: true, data: { enabled }, meta: { requestId: req.id } });
  }

  /**
   * Manual trigger for the expiry reconciliation sweep (blueprint §I): transitions
   * subscriptions whose currentPeriodEnd has passed to EXPIRED. Idempotent —
   * re-running is a no-op. SUPER_ADMIN only (manage_system gate on the route).
   */
  async reconcileSubscriptions(req: Request, res: Response) {
    const actor = req.context?.user;
    if (!actor) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const expiredCount = await subscriptionService.reconcileExpiredSubscriptions(actor.id);
    res.status(200).json({ success: true, data: { expiredCount }, meta: { requestId: req.id } });
  }

  async grantUnlimitedAccess(req: Request, res: Response) {
    const actor = req.context?.user;
    if (!actor) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const orgId = req.params.orgId as string;
    const subscription = await subscriptionService.grantUnlimitedAccess(orgId, actor.id, actor.role);
    res.status(200).json({
      success: true,
      data: { orgId, subscriptionId: subscription.id, unlimitedAccess: subscription.unlimitedAccess },
      meta: { requestId: req.id },
    });
  }

  async revokeUnlimitedAccess(req: Request, res: Response) {
    const actor = req.context?.user;
    if (!actor) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authenticated actor is required.' } });
      return;
    }
    const orgId = req.params.orgId as string;
    const subscription = await subscriptionService.revokeUnlimitedAccess(orgId, actor.id, actor.role);
    res.status(200).json({
      success: true,
      data: { orgId, subscriptionId: subscription.id, unlimitedAccess: subscription.unlimitedAccess },
      meta: { requestId: req.id },
    });
  }

  // --- Subscriptions administration (platform view) -----------------------

  async listSubscriptions(req: Request, res: Response) {
    const result = await adminSubscriptionService.listSubscribers({
      status: req.query.status as string | undefined,
      planCode: req.query.plan as string | undefined,
      trial: req.query.trial as string | undefined,
      unlimited: req.query.unlimited as string | undefined,
      search: req.query.search as string | undefined,
      page: parseInt(req.query.page as string || '1', 10),
      limit: parseInt(req.query.limit as string || '25', 10),
    });
    res.status(200).json({
      success: true,
      data: result.subscribers,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        summary: result.summary,
      },
    });
  }

  async getSubscriptionDetail(req: Request, res: Response) {
    const orgId = req.params.orgId as string;
    const data = await adminSubscriptionService.getSubscriberDetail(orgId);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async listPlans(req: Request, res: Response) {
    const plans = await adminSubscriptionService.listPlans();
    res.status(200).json({ success: true, data: plans, meta: { requestId: req.id } });
  }

  async grantOffer(req: Request, res: Response) {
    const actor = requireActor(req);
    const orgId = req.params.orgId as string;
    const { key, value, expiresAt, note } = req.body ?? {};
    const entitlement = await adminSubscriptionService.grantOffer({
      orgId,
      adminId: actor.id,
      key,
      value,
      expiresAt: expiresAt ? new Date(expiresAt) : null,
      note,
      requestId: req.id,
    });
    res.status(201).json({ success: true, data: entitlement, meta: { requestId: req.id } });
  }

  async revokeOffer(req: Request, res: Response) {
    const actor = requireActor(req);
    const orgId = req.params.orgId as string;
    const key = req.params.key as string;
    const result = await adminSubscriptionService.revokeOffer({
      orgId,
      key,
      adminId: actor.id,
      requestId: req.id,
    });
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // --- Platform payments ----------------------------------------------------

  async listPayments(req: Request, res: Response) {
    const result = await adminOpsService.listPayments({
      status: req.query.status as string | undefined,
      provider: req.query.provider as string | undefined,
      search: req.query.search as string | undefined,
      page: parseInt(req.query.page as string || '1', 10),
      limit: parseInt(req.query.limit as string || '25', 10),
    });
    res.status(200).json({
      success: true,
      data: result.payments,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        summary: result.summary,
      },
    });
  }

  async getPaymentDetail(req: Request, res: Response) {
    const data = await adminOpsService.getPaymentDetail(req.params.id as string);
    if (!data) throw new AppError('NOT_FOUND', 'Payment event not found', 404);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  // --- Platform mail supply ---------------------------------------------------

  async getMailOverview(req: Request, res: Response) {
    const data = await adminOpsService.getMailOverview();
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async previewPlatformMail(req: Request, res: Response) {
    const actor = requireActor(req);
    const { subject, body, targetType, targetRole, targetUserId, orgId } = req.body ?? {};
    if (!subject || !body || !targetType) {
      throw new AppError('VALIDATION_ERROR', 'subject, body, and targetType are required.', 400);
    }
    const result = await mailSupplyService.preview({
      actorId: actor.id,
      actorRole: actor.role,
      orgId: orgId ?? undefined,
      subject,
      body,
      targetType,
      targetRole,
      targetUserId,
    });
    res.status(200).json({
      success: true,
      data: { count: result.count, quotaRemaining: result.quotaRemaining },
      meta: { requestId: req.id },
    });
  }

  async sendPlatformMail(req: Request, res: Response) {
    const actor = requireActor(req);
    const { subject, body, targetType, targetRole, targetUserId, orgId } = req.body ?? {};
    if (!subject || !body || !targetType) {
      throw new AppError('VALIDATION_ERROR', 'subject, body, and targetType are required.', 400);
    }
    const result = await mailSupplyService.send({
      actorId: actor.id,
      actorRole: actor.role,
      orgId: orgId ?? undefined,
      subject,
      body,
      targetType,
      targetRole,
      targetUserId,
      requestId: req.id,
      idempotencyKey: typeof req.headers['idempotency-key'] === 'string'
        ? req.headers['idempotency-key']
        : undefined,
    });
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // --- Platform announcements -------------------------------------------------

  async listAnnouncementsAdmin(req: Request, res: Response) {
    const result = await adminOpsService.listAnnouncements({
      search: req.query.search as string | undefined,
      page: parseInt(req.query.page as string || '1', 10),
      limit: parseInt(req.query.limit as string || '25', 10),
    });
    res.status(200).json({
      success: true,
      data: result.announcements,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      },
    });
  }

  // --- Reports / analytics ------------------------------------------------------

  async getReportsOverview(req: Request, res: Response) {
    const data = await adminOpsService.getReportsOverview();
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  // --- Customer Reviews administration --------------------------------------

  async listReviews(req: Request, res: Response) {
    const result = await reviewService.listForAdmin({
      status: req.query.status as string | undefined,
      search: req.query.search as string | undefined,
      orgId: req.query.orgId as string | undefined,
      page: parseInt(req.query.page as string || '1', 10),
      limit: parseInt(req.query.limit as string || '25', 10),
    });
    res.status(200).json({
      success: true,
      data: result.reviews,
      meta: {
        requestId: req.id,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
        summary: result.summary,
      },
    });
  }

  async getReviewSummary(req: Request, res: Response) {
    const summary = await reviewService.getRatingSummary();
    res.status(200).json({ success: true, data: summary, meta: { requestId: req.id } });
  }

  async getReviewDetail(req: Request, res: Response) {
    const data = await reviewService.getDetail(req.params.id as string);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  async moderateReview(req: Request, res: Response) {
    const actor = requireActor(req);
    const reviewId = req.params.id as string;
    const { action, response } = req.body ?? {};
    const review = await reviewService.moderate({
      reviewId,
      adminId: actor.id,
      action,
      response,
      requestId: req.id,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
    });
    res.status(200).json({
      success: true,
      data: {
        id: review.id,
        publicId: review.publicId,
        status: review.status,
        adminResponse: review.adminResponse,
        moderatedAt: review.moderatedAt,
      },
      meta: { requestId: req.id },
    });
  }
}

export const adminController = new AdminController();
