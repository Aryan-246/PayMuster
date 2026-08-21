import {
  payrollRepository,
  type CreatePayrollItem,
} from '../repositories/payroll.repository.js';
import { AppError } from '../lib/app-error.js';
import { eventBus, Events } from '../lib/events.js';

export class PayrollService {
  async listPayroll(orgId: string, payCycleId?: string) {
    return payrollRepository.getPayRuns(orgId, { payCycleId });
  }

  async createPayroll(orgId: string, data: {
    payCycleId: string;
    items: CreatePayrollItem[];
  }) {
    const payRun = await payrollRepository.createCalculatedPayroll(orgId, data);

    eventBus.emitEvent(Events.PAYROLL_CREATED, {
      payRunId: payRun.id,
      orgId,
      payCycleId: data.payCycleId,
      totalAmount: payRun.totalAmount.toString(),
    });

    return payRun;
  }

  async getPayroll(orgId: string, id: string) {
    const payRun = await payrollRepository.getPayRunById(orgId, id);
    if (!payRun) {
      throw new AppError('PAYROLL_NOT_FOUND', 'Payroll record not found', 404);
    }
    return payRun;
  }
}

export const payrollService = new PayrollService();
