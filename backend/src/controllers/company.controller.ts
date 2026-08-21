import { Request, Response } from 'express';
import { companyService } from '../services/company.service.js';
import { joinService } from '../services/join.service.js';
import { promotionService } from '../services/promotion.service.js';
import { ownerService } from '../services/owner.service.js';
import { invitationService } from '../services/invitation.service.js';
import { staffService } from '../services/staff.service.js';
import { UserRole } from '../../generated/prisma/index.js';

export class CompanyController {
  async lookupCompany(req: Request, res: Response) {
    const code = req.query.code as string;
    if (!code) return res.status(400).json({ success: false, error: { message: 'Code is required' } });
    const company = await companyService.lookupByCode(code);
    if (!company) return res.status(404).json({ success: false, error: { message: 'Company not found' } });
    res.status(200).json({ success: true, data: { id: company.id, name: company.name }, meta: { requestId: req.id } });
  }

  async getOverview(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const overview = await companyService.getOverview(orgId);
    res.status(200).json({ success: true, data: overview, meta: { requestId: req.id } });
  }

  async updateSettings(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;
    const settings = await companyService.updateSettings(orgId, req.body, userId);
    res.status(200).json({ success: true, data: settings, meta: { requestId: req.id } });
  }

  // JOIN
  async getJoinRequests(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const requests = await joinService.getJoinRequests(orgId);
    res.status(200).json({ success: true, data: requests, meta: { requestId: req.id } });
  }

  async requestJoin(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;
    const request = await joinService.requestJoin(orgId, userId);
    res.status(201).json({ success: true, data: request, meta: { requestId: req.id } });
  }

  async approveJoin(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const requestId = req.params.id as string;
    const approvedBy = req.context.user!.id;
    const result = await joinService.approveRequest(orgId, requestId, approvedBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async rejectJoin(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const requestId = req.params.id as string;
    const rejectedBy = req.context.user!.id;
    const result = await joinService.rejectRequest(orgId, requestId, rejectedBy, req.body.reason);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // PROMOTION
  async requestPromotion(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;
    const request = await promotionService.requestPromotion(orgId, userId, req.body.requestedRole, req.body.reason);
    res.status(201).json({ success: true, data: request, meta: { requestId: req.id } });
  }

  async approvePromotion(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const requestId = req.params.id as string;
    const approvedBy = req.context.user!.id;
    const result = await promotionService.approveRequest(orgId, requestId, approvedBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // OWNER
  async requestOwnership(req: Request, res: Response) {
    const userId = req.context.user!.id;
    const { companyName, companyAddress, gstin, businessRegistrationUrl, identityProofUrl } = req.body;
    const request = await ownerService.requestOwnership(userId, companyName, gstin, companyAddress, businessRegistrationUrl, identityProofUrl);
    res.status(201).json({ success: true, data: request, meta: { requestId: req.id } });
  }

  async getMyOwnershipRequest(req: Request, res: Response) {
    const userId = req.context.user!.id;
    const request = await ownerService.getMyRequest(userId);
    res.status(200).json({ success: true, data: request, meta: { requestId: req.id } });
  }

  // INVITATION
  async inviteUser(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const invitedBy = req.context.user!.id;
    const { email, role } = req.body;
    const result = await invitationService.inviteUser(orgId, email, role, invitedBy);
    res.status(201).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async acceptInvitation(req: Request, res: Response) {
    const userId = req.context.user!.id;
    const { token } = req.body;
    const result = await invitationService.acceptInvitation(token, userId);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  // STAFF LIFECYCLE
  async changeRole(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const newRole = req.body.newRole as UserRole;
    const result = await staffService.changeRole(orgId, targetUserId, newRole, actionBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async suspendStaff(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const result = await staffService.suspendStaff(orgId, targetUserId, actionBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async restoreStaff(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const result = await staffService.restoreStaff(orgId, targetUserId, actionBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }

  async terminateStaff(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const targetUserId = req.params.id as string;
    const actionBy = req.context.user!.id;
    const result = await staffService.terminateStaff(orgId, targetUserId, actionBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
  }
}

export const companyController = new CompanyController();
