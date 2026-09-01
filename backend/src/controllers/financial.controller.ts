import { Request, Response } from 'express';
import { financialIntegrityService } from '../services/financial-integrity.service.js';

// Thin transport layer over FinancialIntegrityService. The organization scope is
// always taken from the tenant context established by requireTenant — never from
// the request body — so a client cannot allocate, approve, or attach evidence
// across tenants. The authenticated user is the recorded actor on the ledger row.
export class FinancialController {
  async createAllocation(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const createdById = req.context.user!.id;
    const allocation = await financialIntegrityService.createAllocation(orgId, createdById, req.body);
    res.status(201).json({ success: true, data: allocation, meta: { requestId: req.id } });
  }

  async appendExpenseApproval(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const actorId = req.context.user!.id;
    const approval = await financialIntegrityService.appendExpenseApproval(orgId, actorId, req.body);
    res.status(201).json({ success: true, data: approval, meta: { requestId: req.id } });
  }

  async attachEvidence(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const uploadedById = req.context.user!.id;
    const evidence = await financialIntegrityService.attachEvidence(orgId, uploadedById, req.body);
    res.status(201).json({ success: true, data: evidence, meta: { requestId: req.id } });
  }

  async listPayments(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const { staffId, status, page, limit } = res.locals.validatedQuery as {
      staffId?: string;
      status?: string;
      page: number;
      limit: number;
    };
    const result = await financialIntegrityService.listPayments(orgId, { staffId, status, page, limit });
    res.status(200).json({
      success: true,
      data: result.payments,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages },
    });
  }

  async listExpenses(req: Request, res: Response) {
    const orgId = req.context.tenant!.companyId!;
    const { siteId, status, category, page, limit } = res.locals.validatedQuery as {
      siteId?: string;
      status?: string;
      category?: string;
      page: number;
      limit: number;
    };
    const result = await financialIntegrityService.listExpenses(orgId, { siteId, status, category, page, limit });
    res.status(200).json({
      success: true,
      data: result.expenses,
      meta: { requestId: req.id, total: result.total, page: result.page, totalPages: result.totalPages },
    });
  }
}

export const financialController = new FinancialController();
