import { Request, Response } from 'express';
import { payrollService } from '../services/payroll.service.js';

export class PayrollController {
  async listPayroll(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const { payCycleId } = res.locals.validatedQuery as { payCycleId?: string };
    const records = await payrollService.listPayroll(companyId, payCycleId);
    res.status(200).json({ success: true, data: records, meta: { requestId: req.id } });
  }

  async createPayroll(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const record = await payrollService.createPayroll(companyId, req.body);
    res.status(201).json({ success: true, data: record, meta: { requestId: req.id } });
  }

  async getPayroll(req: Request, res: Response) {
    const companyId = req.context.tenant!.companyId!;
    const id = req.params.id as string;
    const record = await payrollService.getPayroll(companyId, id);
    res.status(200).json({ success: true, data: record, meta: { requestId: req.id } });
  }
}

export const payrollController = new PayrollController();
