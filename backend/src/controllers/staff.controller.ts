import { Request, Response } from 'express';
import { staffDirectoryService } from '../services/staff-directory.service.js';

export class StaffController {
  async listStaff(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const search = (req.query.search ?? req.query.q) as string | undefined;
    const status = req.query.status as string | undefined;
    const workerType = req.query.workerType as string | undefined;

    const pageRaw = parseInt(String(req.query.page ?? ''), 10);
    const limitRaw = parseInt(String(req.query.limit ?? ''), 10);
    const page = Number.isFinite(pageRaw) && pageRaw > 0 ? pageRaw : 1;
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(100, limitRaw) : 50;

    const result = await staffDirectoryService.listStaff(orgId, { search, status, workerType, page, limit });
    res.status(200).json({
      success: true,
      data: result.staff,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages },
    });
  }

  async getStaffById(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const staffId = req.params.id as string;
    const data = await staffDirectoryService.getStaffById(orgId, staffId);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  // Enriched Owner/ADMIN profile read — manage_staff-gated at the route.
  async getStaffProfile(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const staffId = req.params.id as string;
    const data = await staffDirectoryService.getStaffProfile(orgId, staffId);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  // Manual worker add (owner.txt staff section).
  async createStaff(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const actorId = req.context.user!.id;
    const staff = await staffDirectoryService.createStaff(orgId, actorId, req.body);
    res.status(201).json({ success: true, data: staff, meta: { requestId: req.id } });
  }

  // Document review queue for one worker (manage_documents audience).
  async listStaffDocuments(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const staffId = req.params.id as string;
    const status = req.query.status as string | undefined;
    const data = await staffDirectoryService.listStaffDocuments(orgId, staffId, status);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }

  // Approve / reject / verify a worker document (owner blue-tick flow).
  async reviewStaffDocument(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const reviewerId = req.context.user!.id;
    const staffId = req.params.id as string;
    const documentId = req.params.documentId as string;
    const data = await staffDirectoryService.reviewStaffDocument(orgId, staffId, documentId, reviewerId, req.body);
    res.status(200).json({ success: true, data, meta: { requestId: req.id } });
  }
}

export const staffController = new StaffController();
