import { prisma } from '../lib/prisma.js';
import { AllocationType, ExpenseApprovalAction } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';

type FinancialSource = {
    expenseId?: string;
    paymentId?: string;
    payRunId?: string;
};

export interface CreateAllocationInput extends FinancialSource {
    amount: string;
    allocationType: AllocationType;
    siteId?: string;
    notes?: string;
}

export interface AppendExpenseApprovalInput {
    expenseId: string;
    action: ExpenseApprovalAction;
    notes?: string;
}

export interface AttachEvidenceInput extends FinancialSource {
    storageKey: string;
    sha256: string;
    mimeType: string;
    byteSize: number;
}

type DatabaseClient = typeof prisma;

function sourceIds(input: FinancialSource): string[] {
    return [input.expenseId, input.paymentId, input.payRunId].filter(
        (value): value is string => Boolean(value),
    );
}

function assertPositiveDecimal(value: string): void {
    if (!/^(?:0|[1-9]\d*)(?:\.\d{1,6})?$/.test(value) || /^0+(?:\.0{1,6})?$/.test(value)) {
        throw new AppError(
            'FINANCIAL_AMOUNT_INVALID',
            'Financial amounts must be positive decimal strings with up to six fractional digits.',
            400,
        );
    }
}

function assertOneSource(input: FinancialSource): void {
    if (sourceIds(input).length !== 1) {
        throw new AppError(
            'FINANCIAL_SOURCE_INVALID',
            'Exactly one expense, payment, or pay-run source is required.',
            400,
        );
    }
}

export class FinancialIntegrityService {
    constructor(private readonly db: DatabaseClient = prisma) { }

    async createAllocation(orgId: string, createdById: string, input: CreateAllocationInput) {
        assertPositiveDecimal(input.amount);
        assertOneSource(input);
        if (input.allocationType === AllocationType.SITE && !input.siteId) {
            throw new AppError('FINANCIAL_SITE_REQUIRED', 'Site allocations must reference a site.', 400);
        }
        if (input.allocationType !== AllocationType.SITE && input.siteId) {
            throw new AppError('FINANCIAL_SITE_NOT_ALLOWED', 'Only site allocations may reference a site.', 400);
        }

        return this.db.$transaction(async (tx) => {
            await this.assertActor(tx, orgId, createdById);
            await this.assertSource(tx, orgId, input);
            if (input.siteId) await this.assertSite(tx, orgId, input.siteId);

            return tx.financialAllocation.create({
                data: {
                    orgId,
                    amount: input.amount,
                    allocationType: input.allocationType,
                    expenseId: input.expenseId,
                    paymentId: input.paymentId,
                    payRunId: input.payRunId,
                    siteId: input.siteId,
                    createdById,
                    notes: input.notes,
                },
            });
        });
    }

    async appendExpenseApproval(orgId: string, actorId: string, input: AppendExpenseApprovalInput) {
        return this.db.$transaction(async (tx) => {
            await this.assertActor(tx, orgId, actorId);
            const expense = await tx.expense.findFirst({
                where: { id: input.expenseId, orgId, deletedAt: null },
                select: { id: true },
            });
            if (!expense) {
                throw new AppError('EXPENSE_NOT_FOUND', 'Expense not found in this company.', 404);
            }

            return tx.expenseApproval.create({
                data: {
                    orgId,
                    expenseId: input.expenseId,
                    actorId,
                    action: input.action,
                    notes: input.notes,
                },
            });
        });
    }

    async attachEvidence(orgId: string, uploadedById: string, input: AttachEvidenceInput) {
        assertOneSource(input);
        if (!input.storageKey.trim() || !/^[a-f0-9]{64}$/i.test(input.sha256) || !input.mimeType.trim()) {
            throw new AppError('FINANCIAL_EVIDENCE_INVALID', 'Evidence metadata is invalid.', 400);
        }
        if (!Number.isSafeInteger(input.byteSize) || input.byteSize <= 0) {
            throw new AppError('FINANCIAL_EVIDENCE_SIZE_INVALID', 'Evidence size must be a positive safe integer.', 400);
        }

        return this.db.$transaction(async (tx) => {
            await this.assertActor(tx, orgId, uploadedById);
            await this.assertSource(tx, orgId, input);

            return tx.financialEvidence.create({
                data: {
                    orgId,
                    expenseId: input.expenseId,
                    paymentId: input.paymentId,
                    payRunId: input.payRunId,
                    storageKey: input.storageKey.trim(),
                    sha256: input.sha256.toLowerCase(),
                    mimeType: input.mimeType.trim(),
                    byteSize: input.byteSize,
                    uploadedById,
                },
            });
        });
    }

    private async assertActor(tx: any, orgId: string, userId: string): Promise<void> {
        const actor = await tx.user.findFirst({
            where: { id: userId, orgId, deletedAt: null, isActive: true, isDisabled: false },
            select: { id: true },
        });
        if (!actor) {
            throw new AppError('FINANCIAL_ACTOR_NOT_ELIGIBLE', 'The actor is not an active user in this company.', 403);
        }
    }

    private async assertSite(tx: any, orgId: string, siteId: string): Promise<void> {
        const site = await tx.site.findFirst({ where: { id: siteId, orgId, deletedAt: null }, select: { id: true } });
        if (!site) {
            throw new AppError('FINANCIAL_SITE_NOT_FOUND', 'Site not found in this company.', 404);
        }
    }

    private async assertSource(tx: any, orgId: string, input: FinancialSource): Promise<void> {
        if (input.expenseId) {
            const source = await tx.expense.findFirst({ where: { id: input.expenseId, orgId, deletedAt: null }, select: { id: true } });
            if (!source) throw new AppError('EXPENSE_NOT_FOUND', 'Expense not found in this company.', 404);
            return;
        }
        if (input.paymentId) {
            const source = await tx.payment.findFirst({ where: { id: input.paymentId, orgId, deletedAt: null }, select: { id: true } });
            if (!source) throw new AppError('PAYMENT_NOT_FOUND', 'Payment not found in this company.', 404);
            return;
        }
        const source = await tx.payRun.findFirst({ where: { id: input.payRunId, orgId, deletedAt: null }, select: { id: true } });
        if (!source) throw new AppError('PAYROLL_NOT_FOUND', 'Payroll record not found in this company.', 404);
    }
}

export const financialIntegrityService = new FinancialIntegrityService();
