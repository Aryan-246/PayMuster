import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import { PayCycleStatus } from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import {
    PayrollRepository,
    type CreatePayrollItem,
} from './payroll.repository.js';

const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const originalTransaction = mutablePrisma.$transaction;

const orgId = '11111111-1111-4111-8111-111111111111';
const payCycleId = '22222222-2222-4222-8222-222222222222';
const staffIdOne = '33333333-3333-4333-8333-333333333333';
const staffIdTwo = '44444444-4444-4444-8444-444444444444';

const payrollItems: CreatePayrollItem[] = [
    {
        staffId: staffIdOne,
        grossPay: 1000.1,
        deductions: { tax: 100.05, fee: 0.1 },
        additions: { bonus: 20.2 },
        arrears: { retroactivePay: 5.55 },
    },
    {
        staffId: staffIdTwo,
        grossPay: 200.005,
        deductions: { roundingSensitiveDeduction: 0.005 },
        additions: {},
        arrears: {},
    },
];

function assertAppError(
    error: unknown,
    expected: { code: string; status: number },
): boolean {
    assert.ok(error instanceof AppError);
    assert.equal(error.code, expected.code);
    assert.equal(error.status, expected.status);
    return true;
}

function installTransaction(transactionClient: object): void {
    mutablePrisma.$transaction = (async (
        callback: (tx: typeof transactionClient) => unknown,
    ) => callback(transactionClient)) as unknown as typeof prisma.$transaction;
}

function transactionClientFor(options: {
    payCycle?: { id: string; status: PayCycleStatus } | null;
    existingRun?: { id: string } | null;
    activeStaffIds?: string[];
    transitionCount?: number;
    calls?: Array<{ operation: string; args?: unknown }>;
}) {
    const calls = options.calls ?? [];
    return {
        $executeRaw: async (...args: unknown[]) => {
            calls.push({ operation: '$executeRaw', args });
            return 1;
        },
        payCycle: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'payCycle.findFirst', args });
                return options.payCycle === undefined
                    ? { id: payCycleId, status: PayCycleStatus.DRAFT }
                    : options.payCycle;
            },
            updateMany: async (args: unknown) => {
                calls.push({ operation: 'payCycle.updateMany', args });
                return { count: options.transitionCount ?? 1 };
            },
        },
        payRun: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'payRun.findFirst', args });
                return options.existingRun ?? null;
            },
            create: async (args: unknown) => {
                calls.push({ operation: 'payRun.create', args });
                return { id: '55555555-5555-4555-8555-555555555555' };
            },
        },
        staff: {
            findMany: async (args: unknown) => {
                calls.push({ operation: 'staff.findMany', args });
                return (options.activeStaffIds ?? [staffIdOne, staffIdTwo]).map(
                    (id) => ({ id }),
                );
            },
        },
    };
}

afterEach(() => {
    mutablePrisma.$transaction = originalTransaction;
});

test('payroll calculation derives item nets and aggregate total in cents before creating the run', async () => {
    const calls: Array<{ operation: string; args?: unknown }> = [];
    installTransaction(transactionClientFor({ calls }));

    const result = await new PayrollRepository().createCalculatedPayroll(orgId, {
        payCycleId,
        items: payrollItems,
    }) as { id: string };

    assert.equal(result.id, '55555555-5555-4555-8555-555555555555');
    assert.deepEqual(calls.map((call) => call.operation), [
        '$executeRaw',
        'payCycle.findFirst',
        'payRun.findFirst',
        'staff.findMany',
        'payCycle.updateMany',
        'payRun.create',
    ]);

    const rawArgs = calls[0].args as unknown[];
    assert.equal(rawArgs[1], `payroll:${orgId}:${payCycleId}`);

    const staffArgs = calls[3].args as {
        where: Record<string, unknown>;
    };
    assert.deepEqual(staffArgs.where, {
        orgId,
        id: { in: [staffIdOne, staffIdTwo] },
        deletedAt: null,
        status: 'ACTIVE',
    });

    const transitionArgs = calls[4].args as {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
    };
    assert.deepEqual(transitionArgs.where, {
        id: payCycleId,
        orgId,
        deletedAt: null,
        status: PayCycleStatus.DRAFT,
    });
    assert.deepEqual(transitionArgs.data, {
        status: PayCycleStatus.CALCULATED,
    });

    const createArgs = calls[5].args as {
        data: {
            totalAmount: number;
            approvedById?: unknown;
            approvedAt?: unknown;
            payRunItems: {
                create: Array<Record<string, unknown>>;
            };
        };
    };
    assert.equal(createArgs.data.totalAmount, 1125.7);
    assert.equal('approvedById' in createArgs.data, false);
    assert.equal('approvedAt' in createArgs.data, false);
    assert.deepEqual(
        createArgs.data.payRunItems.create.map((item) => item.netPay),
        [925.7, 200],
    );
    assert.equal(
        createArgs.data.payRunItems.create.every(
            (item) => !('approvedById' in item) && !('approvedAt' in item),
        ),
        true,
    );
});

test('payroll calculation rejects invalid cycle and staff states without lifecycle or pay-run writes', async (context) => {
    const scenarios: Array<{
        name: string;
        options: Parameters<typeof transactionClientFor>[0];
        code: string;
        status: number;
    }> = [
            {
                name: 'missing pay cycle',
                options: { payCycle: null },
                code: 'PAY_CYCLE_NOT_FOUND',
                status: 404,
            },
            {
                name: 'non-draft pay cycle',
                options: {
                    payCycle: { id: payCycleId, status: PayCycleStatus.CALCULATED },
                },
                code: 'PAY_CYCLE_NOT_DRAFT',
                status: 409,
            },
            {
                name: 'existing active pay run',
                options: { existingRun: { id: 'existing-pay-run' } },
                code: 'PAYROLL_ALREADY_EXISTS',
                status: 409,
            },
            {
                name: 'inactive, missing, or cross-company staff',
                options: { activeStaffIds: [staffIdOne] },
                code: 'PAYROLL_STAFF_NOT_ELIGIBLE',
                status: 400,
            },
        ];

    for (const scenario of scenarios) {
        await context.test(scenario.name, async () => {
            const calls: Array<{ operation: string; args?: unknown }> = [];
            installTransaction(transactionClientFor({
                ...scenario.options,
                calls,
            }));

            await assert.rejects(
                new PayrollRepository().createCalculatedPayroll(orgId, {
                    payCycleId,
                    items: payrollItems,
                }),
                (error) => assertAppError(error, {
                    code: scenario.code,
                    status: scenario.status,
                }),
            );
            assert.equal(
                calls.some((call) => call.operation === 'payCycle.updateMany'),
                false,
            );
            assert.equal(
                calls.some((call) => call.operation === 'payRun.create'),
                false,
            );
        });
    }
});

test('payroll calculation rejects negative server-derived net pay before any write', async () => {
    const calls: Array<{ operation: string; args?: unknown }> = [];
    installTransaction(transactionClientFor({
        activeStaffIds: [staffIdOne],
        calls,
    }));

    await assert.rejects(
        new PayrollRepository().createCalculatedPayroll(orgId, {
            payCycleId,
            items: [{
                staffId: staffIdOne,
                grossPay: 10,
                deductions: { recovery: 10.01 },
                additions: {},
                arrears: {},
            }],
        }),
        (error) => assertAppError(error, {
            code: 'PAYROLL_NEGATIVE_NET',
            status: 400,
        }),
    );
    assert.equal(
        calls.some((call) => call.operation === 'payCycle.updateMany'),
        false,
    );
    assert.equal(
        calls.some((call) => call.operation === 'payRun.create'),
        false,
    );
});

test('payroll calculation treats a lost draft transition as a conflict and creates no run', async () => {
    const calls: Array<{ operation: string; args?: unknown }> = [];
    installTransaction(transactionClientFor({ transitionCount: 0, calls }));

    await assert.rejects(
        new PayrollRepository().createCalculatedPayroll(orgId, {
            payCycleId,
            items: payrollItems,
        }),
        (error) => assertAppError(error, {
            code: 'PAY_CYCLE_CONFLICT',
            status: 409,
        }),
    );
    assert.equal(
        calls.filter((call) => call.operation === 'payCycle.updateMany').length,
        1,
    );
    assert.equal(
        calls.some((call) => call.operation === 'payRun.create'),
        false,
    );
});
