import { prisma } from '../lib/prisma.js';
import { PayCycleStatus, StaffStatus } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';

export type PayrollAdjustments = Record<string, number>;

export interface CreatePayrollItem {
  staffId: string;
  grossPay: number;
  deductions: PayrollAdjustments;
  additions: PayrollAdjustments;
  arrears: PayrollAdjustments;
}

const payRunInclude = {
  payCycle: { select: { id: true, startDate: true, endDate: true, status: true } },
  approvedBy: { select: { id: true, firstName: true, lastName: true } },
  payRunItems: {
    where: { deletedAt: null },
    select: {
      id: true,
      staffId: true,
      grossPay: true,
      deductions: true,
      additions: true,
      arrears: true,
      netPay: true,
      staff: {
        select: {
          id: true,
          publicId: true,
          firstName: true,
          lastName: true,
          workerType: true,
          status: true,
        },
      },
    },
  },
};

function toCents(amount: number): number {
  return Math.round((amount + Number.EPSILON) * 100);
}

function adjustmentCents(adjustments: PayrollAdjustments): number {
  return Object.values(adjustments).reduce((sum, amount) => sum + toCents(amount), 0);
}

function itemNetCents(item: CreatePayrollItem): number {
  return (
    toCents(item.grossPay) -
    adjustmentCents(item.deductions) +
    adjustmentCents(item.additions) +
    adjustmentCents(item.arrears)
  );
}

export class PayrollRepository {
  async createCalculatedPayroll(
    orgId: string,
    data: { payCycleId: string; items: CreatePayrollItem[] },
  ) {
    return prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`payroll:${orgId}:${data.payCycleId}`}, 0))`;

      const [payCycle, existingRun, activeStaff] = await Promise.all([
        tx.payCycle.findFirst({
          where: { id: data.payCycleId, orgId, deletedAt: null },
          select: { id: true, status: true },
        }),
        tx.payRun.findFirst({
          where: { orgId, payCycleId: data.payCycleId, deletedAt: null },
          select: { id: true },
        }),
        tx.staff.findMany({
          where: {
            orgId,
            id: { in: data.items.map((item) => item.staffId) },
            deletedAt: null,
            status: StaffStatus.ACTIVE,
          },
          select: { id: true },
        }),
      ]);

      if (!payCycle) {
        throw new AppError('PAY_CYCLE_NOT_FOUND', 'Pay cycle not found.', 404);
      }
      if (payCycle.status !== PayCycleStatus.DRAFT) {
        throw new AppError('PAY_CYCLE_NOT_DRAFT', 'Only a draft pay cycle can be calculated.', 409);
      }
      if (existingRun) {
        throw new AppError('PAYROLL_ALREADY_EXISTS', 'An active payroll run already exists for this pay cycle.', 409);
      }

      const activeStaffIds = new Set(activeStaff.map((staff) => staff.id));
      const ineligibleStaffIds = data.items
        .map((item) => item.staffId)
        .filter((staffId) => !activeStaffIds.has(staffId));
      if (ineligibleStaffIds.length > 0) {
        throw new AppError(
          'PAYROLL_STAFF_NOT_ELIGIBLE',
          'Every payroll item must reference active staff in this company.',
          400,
        );
      }

      const calculatedItems = data.items.map((item) => {
        const netCents = itemNetCents(item);
        if (netCents < 0) {
          throw new AppError('PAYROLL_NEGATIVE_NET', 'Payroll adjustments cannot produce negative net pay.', 400);
        }
        return { ...item, netPay: netCents / 100 };
      });
      const totalAmount = calculatedItems.reduce(
        (sum, item) => sum + toCents(item.netPay),
        0,
      ) / 100;

      const transition = await tx.payCycle.updateMany({
        where: {
          id: data.payCycleId,
          orgId,
          deletedAt: null,
          status: PayCycleStatus.DRAFT,
        },
        data: { status: PayCycleStatus.CALCULATED },
      });
      if (transition.count !== 1) {
        throw new AppError('PAY_CYCLE_CONFLICT', 'The pay cycle changed while payroll was being calculated.', 409);
      }

      return tx.payRun.create({
        data: {
          orgId,
          payCycleId: data.payCycleId,
          totalAmount,
          payRunItems: {
            create: calculatedItems.map((item) => ({
              orgId,
              staffId: item.staffId,
              grossPay: item.grossPay,
              deductions: item.deductions,
              additions: item.additions,
              arrears: item.arrears,
              netPay: item.netPay,
            })),
          },
        },
        include: payRunInclude,
      });
    });
  }

  async getPayRuns(orgId: string, filters: { payCycleId?: string } = {}) {
    return prisma.payRun.findMany({
      where: {
        orgId,
        deletedAt: null,
        ...(filters.payCycleId && { payCycleId: filters.payCycleId }),
      },
      orderBy: { createdAt: 'desc' },
      include: payRunInclude,
    });
  }

  async getPayRunById(orgId: string, id: string) {
    return prisma.payRun.findFirst({
      where: { id, orgId, deletedAt: null },
      include: payRunInclude,
    });
  }
}

export const payrollRepository = new PayrollRepository();
