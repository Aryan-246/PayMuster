import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';

import {
    AttendanceStatus,
    ShiftType,
} from '../../generated/prisma/index.js';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import {
    AttendanceRepository,
    type CreateAttendanceData,
} from './attendance.repository.js';

const mutablePrisma = prisma as unknown as {
    $transaction: typeof prisma.$transaction;
};
const originalTransaction = mutablePrisma.$transaction;

const orgId = '11111111-1111-4111-8111-111111111111';
const staffId = '22222222-2222-4222-8222-222222222222';
const siteId = '33333333-3333-4333-8333-333333333333';
const markerId = '44444444-4444-4444-8444-444444444444';

const attendanceData: CreateAttendanceData = {
    staffId,
    siteId,
    date: new Date('2026-08-17T18:45:12.000Z'),
    status: AttendanceStatus.PRESENT,
    shiftType: ShiftType.REGULAR,
    markedById: markerId,
};

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

afterEach(() => {
    mutablePrisma.$transaction = originalTransaction;
});

test('attendance creation locks and persists the normalized UTC business day after all eligibility checks', async () => {
    const calls: Array<{ operation: string; args?: unknown }> = [];
    const transactionClient = {
        $executeRaw: async (...args: unknown[]) => {
            calls.push({ operation: '$executeRaw', args });
            return 1;
        },
        staff: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'staff.findFirst', args });
                return { id: staffId };
            },
        },
        site: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'site.findFirst', args });
                return { id: siteId };
            },
        },
        siteAssignment: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'siteAssignment.findFirst', args });
                return { id: '55555555-5555-4555-8555-555555555555' };
            },
        },
        attendanceRecord: {
            findFirst: async (args: unknown) => {
                calls.push({ operation: 'attendanceRecord.findFirst', args });
                return null;
            },
            create: async (args: unknown) => {
                calls.push({ operation: 'attendanceRecord.create', args });
                return { id: '66666666-6666-4666-8666-666666666666' };
            },
        },
    };
    installTransaction(transactionClient);

    const result = await new AttendanceRepository().createAttendance(
        orgId,
        attendanceData,
    ) as { id: string };

    assert.equal(result.id, '66666666-6666-4666-8666-666666666666');
    assert.deepEqual(calls.map((call) => call.operation), [
        '$executeRaw',
        'staff.findFirst',
        'site.findFirst',
        'siteAssignment.findFirst',
        'attendanceRecord.findFirst',
        'attendanceRecord.create',
    ]);

    const rawArgs = calls[0].args as unknown[];
    assert.equal(
        rawArgs[1],
        `attendance:${orgId}:${staffId}:2026-08-17T00:00:00.000Z`,
    );

    const staffArgs = calls[1].args as { where: Record<string, unknown> };
    assert.deepEqual(staffArgs.where, {
        id: staffId,
        orgId,
        deletedAt: null,
        status: 'ACTIVE',
    });

    const assignmentArgs = calls[3].args as {
        where: Record<string, unknown>;
    };
    assert.deepEqual(assignmentArgs.where, {
        orgId,
        siteId,
        staffId,
        removedAt: null,
        deletedAt: null,
    });

    const duplicateArgs = calls[4].args as {
        where: { date: { gte: Date; lt: Date } };
    };
    assert.equal(
        duplicateArgs.where.date.gte.toISOString(),
        '2026-08-17T00:00:00.000Z',
    );
    assert.equal(
        duplicateArgs.where.date.lt.toISOString(),
        '2026-08-18T00:00:00.000Z',
    );

    const createArgs = calls[5].args as {
        data: Record<string, unknown>;
    };
    assert.equal(
        (createArgs.data.date as Date).toISOString(),
        '2026-08-17T00:00:00.000Z',
    );
    assert.equal(createArgs.data.shiftType, ShiftType.REGULAR);
    assert.equal(createArgs.data.markedById, markerId);
});

test('attendance creation rejects inactive or cross-company staff without writing', async () => {
    let createCount = 0;
    installTransaction({
        $executeRaw: async () => 1,
        staff: { findFirst: async () => null },
        site: { findFirst: async () => ({ id: siteId }) },
        siteAssignment: { findFirst: async () => ({ id: 'assignment-id' }) },
        attendanceRecord: {
            findFirst: async () => null,
            create: async () => {
                createCount += 1;
                return {};
            },
        },
    });

    await assert.rejects(
        new AttendanceRepository().createAttendance(orgId, attendanceData),
        (error) => assertAppError(error, {
            code: 'ATTENDANCE_STAFF_NOT_ELIGIBLE',
            status: 400,
        }),
    );
    assert.equal(createCount, 0);
});

test('attendance creation rejects inactive sites and missing active assignments without writing', async (context) => {
    for (const scenario of [
        {
            name: 'inactive or cross-company site',
            site: null,
            assignment: { id: 'assignment-id' },
            code: 'ATTENDANCE_SITE_NOT_ACTIVE',
        },
        {
            name: 'missing active assignment',
            site: { id: siteId },
            assignment: null,
            code: 'ATTENDANCE_ASSIGNMENT_REQUIRED',
        },
    ]) {
        await context.test(scenario.name, async () => {
            let createCount = 0;
            installTransaction({
                $executeRaw: async () => 1,
                staff: { findFirst: async () => ({ id: staffId }) },
                site: { findFirst: async () => scenario.site },
                siteAssignment: { findFirst: async () => scenario.assignment },
                attendanceRecord: {
                    findFirst: async () => null,
                    create: async () => {
                        createCount += 1;
                        return {};
                    },
                },
            });

            await assert.rejects(
                new AttendanceRepository().createAttendance(orgId, attendanceData),
                (error) => assertAppError(error, {
                    code: scenario.code,
                    status: 400,
                }),
            );
            assert.equal(createCount, 0);
        });
    }
});

test('attendance creation rejects an existing same-day record without writing', async () => {
    let createCount = 0;
    installTransaction({
        $executeRaw: async () => 1,
        staff: { findFirst: async () => ({ id: staffId }) },
        site: { findFirst: async () => ({ id: siteId }) },
        siteAssignment: { findFirst: async () => ({ id: 'assignment-id' }) },
        attendanceRecord: {
            findFirst: async () => ({ id: 'existing-attendance-id' }),
            create: async () => {
                createCount += 1;
                return {};
            },
        },
    });

    await assert.rejects(
        new AttendanceRepository().createAttendance(orgId, attendanceData),
        (error) => assertAppError(error, {
            code: 'ATTENDANCE_ALREADY_MARKED',
            status: 409,
        }),
    );
    assert.equal(createCount, 0);
});
