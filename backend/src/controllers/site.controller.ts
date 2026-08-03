import { Request, Response } from 'express';
import { siteService } from '../services/site.service.js';
import { SiteStatus } from '../../generated/prisma/index.js';

export class SiteController {
  async createSite(req: Request, res: Response) {
    const { name, address } = req.body;
    const orgId = req.context.tenant!.companyId!;
    const userId = req.context.user!.id;

    const site = await siteService.createSite(orgId, userId, { name, address });

    res.status(201).json({
      success: true,
      data: site,
      meta: { requestId: req.id, timestamp: new Date().toISOString() }
    });
  }

  async getSites(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const status = req.query.status as SiteStatus;

    const sites = await siteService.getSites(orgId, status);

    res.status(200).json({
      success: true,
      data: sites,
      meta: { requestId: req.id, timestamp: new Date().toISOString() }
    });
  }

  async getSiteDetails(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const siteId = req.context.tenant!.siteId!; // tenant middleware ensures it is valid

    const site = await siteService.getSiteDetails(orgId, siteId);

    res.status(200).json({
      success: true,
      data: site,
      meta: { requestId: req.id, timestamp: new Date().toISOString() }
    });
  }

  async updateStatus(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const siteId = req.params.siteId as string;
    const userId = req.context.user!.id;
    const { status, reason } = req.body;

    const updatedSite = await siteService.updateSiteStatus(orgId, siteId, status, userId, reason);
    res.status(200).json({ success: true, data: updatedSite, meta: { requestId: req.id, timestamp: new Date().toISOString() } });
  }

  async assignWorker(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const siteId = req.params.siteId as string;
    const assignedBy = req.context.user!.id;
    const { userId, role } = req.body;

    const result = await siteService.assignWorker(orgId, siteId, userId, role, assignedBy);
    res.status(200).json({ success: true, data: result, meta: { requestId: req.id, timestamp: new Date().toISOString() } });
  }
}

export const siteController = new SiteController();
