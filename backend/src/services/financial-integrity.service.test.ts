import assert from 'node:assert/strict';
import test from 'node:test';

import { AllocationType, ExpenseApprovalAction } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import {
    FinancialIntegrityService,
    type AttachEvidenceInput,
    type CreateAllocationInput,
} from './financial-integrity.service.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const otherOrgId = '22222222-2222-4222-8222-222222222222';
const actorId = '33333333-3333-4333-8333-333333333333';
const expenseId = '44444444-4444-4444-8444-444444444444';
const paymentId = '55555555-5555-4555-8555-555555555555';
const siteId = '66666666-6666-4666-8666-666666666666';

function expectAppError(promise: Promise<unknown>, code: string): Promise<void> {
    return promise.then(
        () => assert.fail(`Expected ${code} to be thrown`),
        (error: unknown) => {
            assert.ok(error instanceof AppError);
            assert.equal(error.code, code);
        },
    );
}

function baseTx(overrides: Record<string, unknown> = {}) {
    const calls: Array<{ delegate: string; args: any }> = [];
    const tx: Record<string, any> = {
        user: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'user.findFirst', args });
                return { id: actorId };
            },
        },
        expense: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'expense.findFirst', args });
                return { id: expenseId };
            },
        },
        payment: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'payment.findFirst', args });
                return { id: paymentId };
            },
        },
        payRun: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'payRun.findFirst', args });
                return { id: '77777777-7777-4777-8777-777777777777' };
            },
        },
        site: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'site.findFirst', args });
                return { id: siteId };
            },
        },
        financialAllocation: {
            create: async (args: any) => {
                calls.push({ delegate: 'financialAllocation.create', args });
                return { id: '88888888-8888-4888-8888-888888888888', ...args.data };
            },
        },
        expenseApproval: {
            create: async (args: any) => {
                calls.push({ delegate: 'expenseApproval.create', args });
                return { id: '99999999-9999-4999-8999-999999999999', ...args.data };
            },
        },
        financialEvidence: {
            create: async (args: any) => {
                calls.push({ delegate: 'financialEvidence.create', args });
                return { id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', ...args.data };
            },
        },
        ...overrides,
    };
    return { tx, calls };
}

function serviceFor(tx: any): FinancialIntegrityService {
    return new FinancialIntegrityService({
        $transaction: async (callback: (client: any) => Promise<unknown>) => callback(tx),
    } as any);
}

test('allocation preserves the exact Decimal input and scopes every lookup to the organization', async () => {
    const { tx, calls } = baseTx();
    const service = serviceFor(tx);
    const input: CreateAllocationInput = {
        amount: '100.125000',
        allocationType: AllocationType.SITE,
        expenseId,
        siteId,
        notes: 'materials allocation',
    };

    const result = await service.createAllocation(orgId, actorId, input);

    assert.equal(result.amount, input.amount);
    assert.equal(result.orgId, orgId);
    assert.equal(calls.find((call) => call.delegate === 'expense.findFirst')?.args.where.orgId, orgId);
    assert.equal(calls.find((call) => call.delegate === 'site.findFirst')?.args.where.orgId, orgId);
    assert.equal(calls.find((call) => call.delegate === 'financialAllocation.create')?.args.data.amount, '100.125000');
});

test('cross-tenant payment allocation is rejected before a ledger row is created', async () => {
    const { tx, calls } = baseTx({
        payment: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'payment.findFirst', args });
                assert.equal(args.where.orgId, orgId);
                return null;
            },
        },
    });
    const service = serviceFor(tx);

    await expectAppError(
        service.createAllocation(orgId, actorId, {
            amount: '25.50',
            allocationType: AllocationType.COMPANY,
            paymentId,
        }),
        'PAYMENT_NOT_FOUND',
    );
    assert.equal(calls.some((call) => call.delegate === 'financialAllocation.create'), false);
});

test('allocation rejects zero or multiple sources before opening a transaction', async () => {
    let transactions = 0;
    const service = new FinancialIntegrityService({
        $transaction: async () => {
            transactions += 1;
            return null;
        },
    } as any);

    await expectAppError(
        service.createAllocation(orgId, actorId, {
            amount: '0.00',
            allocationType: AllocationType.COMPANY,
            expenseId,
        }),
        'FINANCIAL_AMOUNT_INVALID',
    );
    await expectAppError(
        service.createAllocation(orgId, actorId, {
            amount: '10.00',
            allocationType: AllocationType.COMPANY,
            expenseId,
            paymentId,
        }),
        'FINANCIAL_SOURCE_INVALID',
    );
    assert.equal(transactions, 0);
});

test('expense approval is append-only and tenant-scoped', async () => {
    const { tx, calls } = baseTx();
    const service = serviceFor(tx);

    const result = await service.appendExpenseApproval(orgId, actorId, {
        expenseId,
        action: ExpenseApprovalAction.APPROVED,
        notes: 'reviewed receipt',
    });

    assert.equal(result.orgId, orgId);
    assert.equal(result.action, ExpenseApprovalAction.APPROVED);
    assert.equal(calls.some((call) => call.delegate === 'expense.update'), false);
    assert.equal(calls.find((call) => call.delegate === 'expenseApproval.create')?.args.data.orgId, orgId);
});

test('evidence normalizes safe metadata and rejects a cross-tenant source', async () => {
    const { tx, calls } = baseTx({
        payment: {
            findFirst: async (args: any) => {
                calls.push({ delegate: 'payment.findFirst', args });
                return null;
            },
        },
    });
    const service = serviceFor(tx);
    const input: AttachEvidenceInput = {
        paymentId,
        storageKey: 'private/receipts/payment-1.pdf',
        sha256: 'A'.repeat(64),
        mimeType: ' application/pdf ',
        byteSize: 1024,
    };

    await expectAppError(service.attachEvidence(orgId, actorId, input), 'PAYMENT_NOT_FOUND');
    assert.equal(calls.some((call) => call.delegate === 'financialEvidence.create'), false);

    const successful = baseTx();
    const successfulService = serviceFor(successful.tx);
    const evidence = await successfulService.attachEvidence(orgId, actorId, {
        expenseId,
        ...input,
        paymentId: undefined,
    });
    assert.equal(evidence.sha256, 'a'.repeat(64));
    assert.equal(evidence.mimeType, 'application/pdf');
});

test('listPayments scopes to the org, applies filters, and paginates', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const db: Record<string, any> = {
        payment: {
            findMany: async (args: any) => {
                calls.push({ delegate: 'payment.findMany', args });
                return [{ id: paymentId, amount: '500.00', staff: { firstName: 'Asha' } }];
            },
            count: async (args: any) => {
                calls.push({ delegate: 'payment.count', args });
                return 1;
            },
        },
    };
    const service = new FinancialIntegrityService(db as any);

    const result = await service.listPayments(orgId, {
        staffId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        status: 'PAID',
        page: 2,
        limit: 25,
    });

    const findArgs = calls.find((call) => call.delegate === 'payment.findMany')!.args;
    const countArgs = calls.find((call) => call.delegate === 'payment.count')!.args;
    assert.equal(findArgs.where.orgId, orgId);
    assert.equal(findArgs.where.deletedAt, null);
    assert.equal(findArgs.where.staffId, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    assert.equal(findArgs.where.status, 'PAID');
    assert.equal(findArgs.skip, 25);
    assert.equal(findArgs.take, 25);
    assert.deepEqual(countArgs.where, findArgs.where);
    assert.equal(result.total, 1);
    assert.equal(result.totalPages, 1);
    assert.equal(result.payments[0].amount, '500.00');
});

test('listPayments never exposes bank fields — only payment lifecycle data', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const db: Record<string, any> = {
        payment: {
            findMany: async (args: any) => {
                calls.push({ delegate: 'payment.findMany', args });
                return [];
            },
            count: async () => 0,
        },
    };
    const service = new FinancialIntegrityService(db as any);

    await service.listPayments(orgId, { page: 1, limit: 50 });

    const selected = Object.keys(calls.find((call) => call.delegate === 'payment.findMany')!.args.select);
    assert.ok(selected.includes('amount'));
    assert.ok(selected.includes('status'));
    assert.equal(selected.includes('staffId'), false);
});

test('listExpenses scopes to the org, includes approvals, and paginates', async () => {
    const calls: Array<{ delegate: string; args: any }> = [];
    const db: Record<string, any> = {
        expense: {
            findMany: async (args: any) => {
                calls.push({ delegate: 'expense.findMany', args });
                return [{
                    id: expenseId,
                    amount: '1200.50',
                    site: { name: 'Mohali Tower' },
                    approvals: [{ action: 'APPROVED' }],
                }];
            },
            count: async (args: any) => {
                calls.push({ delegate: 'expense.count', args });
                return 11;
            },
        },
    };
    const service = new FinancialIntegrityService(db as any);

    const result = await service.listExpenses(orgId, {
        siteId,
        status: 'APPROVED',
        category: 'cement',
        page: 1,
        limit: 10,
    });

    const findArgs = calls.find((call) => call.delegate === 'expense.findMany')!.args;
    assert.equal(findArgs.where.orgId, orgId);
    assert.equal(findArgs.where.siteId, siteId);
    assert.equal(findArgs.where.status, 'APPROVED');
    assert.equal(findArgs.where.category.mode, 'insensitive');
    assert.equal(findArgs.skip, 0);
    assert.equal(findArgs.take, 10);
    assert.ok(findArgs.select.approvals);
    assert.equal(result.total, 11);
    assert.equal(result.totalPages, 2);
    assert.equal(result.expenses[0].approvals[0].action, 'APPROVED');
});
