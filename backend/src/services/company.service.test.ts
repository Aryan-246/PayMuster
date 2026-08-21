import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { prisma } from '../lib/prisma.js';
import { CompanyService } from './company.service.js';

const organizationDelegate = prisma.organization as unknown as {
    findUnique: typeof prisma.organization.findUnique;
};
const expenseDelegate = prisma.expense as unknown as {
    aggregate: typeof prisma.expense.aggregate;
};
const payRunDelegate = prisma.payRun as unknown as {
    aggregate: typeof prisma.payRun.aggregate;
};

const originalOrganizationFindUnique = organizationDelegate.findUnique;
const originalExpenseAggregate = expenseDelegate.aggregate;
const originalPayRunAggregate = payRunDelegate.aggregate;

const organization = {
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Acme Payroll',
    settings: { currency: 'INR' },
    _count: { users: 12, sites: 3, staff: 9 },
};

afterEach(() => {
    organizationDelegate.findUnique = originalOrganizationFindUnique;
    expenseDelegate.aggregate = originalExpenseAggregate;
    payRunDelegate.aggregate = originalPayRunAggregate;
});

test('company overview scopes independently labeled financial aggregates to the tenant', async () => {
    const expenseCalls: unknown[] = [];
    let organizationArgs: unknown;
    let payRunArgs: unknown;

    organizationDelegate.findUnique = (async (args: unknown) => {
        organizationArgs = args;
        return organization;
    }) as unknown as typeof prisma.organization.findUnique;
    expenseDelegate.aggregate = (async (args: unknown) => {
        expenseCalls.push(args);
        const where = (args as { where: { siteId: unknown } }).where;
        const amount = where.siteId === null ? '300.25' : '1250.50';
        return {
            _sum: {
                amount: {
                    toString: () => amount,
                },
            },
        };
    }) as unknown as typeof prisma.expense.aggregate;
    payRunDelegate.aggregate = (async (args: unknown) => {
        payRunArgs = args;
        return {
            _count: { _all: 4 },
            _sum: { totalAmount: { toString: () => '84500.75' } },
        };
    }) as unknown as typeof prisma.payRun.aggregate;

    const overview = await new CompanyService().getOverview(organization.id);

    assert.deepEqual(organizationArgs, {
        where: { id: organization.id },
        include: {
            settings: true,
            _count: { select: { users: true, sites: true, staff: true } },
        },
    });
    assert.deepEqual(expenseCalls, [
        {
            where: {
                orgId: organization.id,
                deletedAt: null,
                siteId: { not: null },
                status: { in: ['APPROVED', 'REIMBURSED'] },
            },
            _sum: { amount: true },
        },
        {
            where: {
                orgId: organization.id,
                deletedAt: null,
                siteId: null,
                status: { in: ['APPROVED', 'REIMBURSED'] },
            },
            _sum: { amount: true },
        },
    ]);
    assert.deepEqual(payRunArgs, {
        where: { orgId: organization.id, deletedAt: null },
        _count: { _all: true },
        _sum: { totalAmount: true },
    });
    assert.deepEqual(overview.financialSummary, {
        expenses: {
            includedStatuses: ['APPROVED', 'REIMBURSED'],
            siteLinkedTotal: '1250.50',
            companyLevelTotal: '300.25',
        },
        payRuns: {
            recordedCount: 4,
            recordedTotal: '84500.75',
        },
    });
});

test('company overview represents absent financial history with explicit zero values', async () => {
    organizationDelegate.findUnique = (async () => organization) as unknown as typeof prisma.organization.findUnique;
    expenseDelegate.aggregate = (async () => ({
        _sum: { amount: null },
    })) as unknown as typeof prisma.expense.aggregate;
    payRunDelegate.aggregate = (async () => ({
        _count: { _all: 0 },
        _sum: { totalAmount: null },
    })) as unknown as typeof prisma.payRun.aggregate;

    const overview = await new CompanyService().getOverview(organization.id);

    assert.equal(overview.financialSummary.expenses.siteLinkedTotal, '0');
    assert.equal(overview.financialSummary.expenses.companyLevelTotal, '0');
    assert.equal(overview.financialSummary.payRuns.recordedCount, 0);
    assert.equal(overview.financialSummary.payRuns.recordedTotal, '0');
});
