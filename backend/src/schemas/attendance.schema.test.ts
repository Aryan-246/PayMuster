import assert from 'node:assert/strict';
import test from 'node:test';
import { createAttendanceSchema } from './attendance.schema.js';

const base = {
    staffId: '11111111-1111-4111-8111-111111111111',
    siteId: '22222222-2222-4222-8222-222222222222',
    date: '2026-08-22T09:00:00.000Z',
    status: 'PRESENT' as const,
    shiftType: 'REGULAR' as const,
};

test('attendance schema requires check-in coordinates for present records', () => {
    const result = createAttendanceSchema.safeParse(base);
    assert.equal(result.success, false);
    if (!result.success) assert.equal(result.error.issues[0]?.path[0], 'checkInLatitude');
});

test('attendance schema rejects partial coordinate pairs and missing capture timestamps', () => {
    const partial = createAttendanceSchema.safeParse({ ...base, checkInLatitude: 12.9 });
    assert.equal(partial.success, false);
    if (!partial.success) assert.ok(partial.error.issues.some((issue) => issue.message.includes('supplied together')));

    const missingCapture = createAttendanceSchema.safeParse({
        ...base,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
    });
    assert.equal(missingCapture.success, false);
    if (!missingCapture.success) assert.ok(missingCapture.error.issues.some((issue) => issue.path[0] === 'checkInCapturedAt'));
});

test('attendance schema accepts a complete location evidence payload', () => {
    const result = createAttendanceSchema.safeParse({
        ...base,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        checkInAccuracyMeters: 12,
        checkInCapturedAt: '2026-08-22T08:59:30.000Z',
        checkOutLatitude: 12.9717,
        checkOutLongitude: 77.5947,
        checkOutAccuracyMeters: 18,
        checkOutCapturedAt: '2026-08-22T17:00:00.000Z',
    });
    assert.equal(result.success, true);
});
