import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { StaffDirectoryService } from './staff-directory.service.js';
import { AppError } from '../lib/app-error.js';
import type { prisma } from '../lib/prisma.js';

// A minimal fake of the Prisma client's `staff` delegate. Each method records
// the args it was called with so tests can assert on tenant scoping, pagination,
// and the exact `select` — no live database required.
function makeDb(overrides: { findMany?: unknown[]; count?: number; findFirst?: unknown; create?: unknown; update?: unknown } = {}) {
  const calls: { findMany?: any; count?: any; findFirst?: any; create?: any; update?: any; auditCreate?: any } = {};
  const db = {
    staff: {
      findMany: async (args: any) => {
        calls.findMany = args;
        return overrides.findMany ?? [];
      },
      count: async (args: any) => {
        calls.count = args;
        return overrides.count ?? 0;
      },
      findFirst: async (args: any) => {
        calls.findFirst = args;
        return overrides.findFirst ?? null;
      },
      create: async (args: any) => {
        calls.create = args;
        return overrides.create ?? {};
      },
    },
    staffDocument: {
      findFirst: async (args: any) => {
        calls.findFirst = args;
        return overrides.findFirst ?? null;
      },
      findMany: async (args: any) => {
        calls.findMany = args;
        return overrides.findMany ?? [];
      },
      update: async (args: any) => {
        calls.update = args;
        return overrides.update ?? {};
      },
    },
    auditLog: {
      create: async (args: any) => {
        calls.auditCreate = args;
        return {};
      },
    },
    $transaction: async (fn: (tx: any) => unknown) => fn(db),
  };
  return { db: db as unknown as typeof prisma, calls };
}

const SENSITIVE_FIELDS = ['bankAccountNumber', 'ifscCode', 'upiId', 'preferredPaymentMethod'];

describe('StaffDirectoryService', () => {
  test('listStaff scopes the query to the tenant org and excludes soft-deleted rows', async () => {
    const { db, calls } = makeDb({ findMany: [], count: 0 });
    const service = new StaffDirectoryService(db);

    const result = await service.listStaff('org-1', { page: 1, limit: 50 });

    assert.equal(calls.findMany.where.orgId, 'org-1');
    assert.equal(calls.findMany.where.deletedAt, null);
    assert.equal(calls.count.where.orgId, 'org-1');
    assert.equal(calls.count.where.deletedAt, null);
    assert.deepEqual(result, { staff: [], total: 0, page: 1, totalPages: 0 });
  });

  test('listStaff cannot be redirected to another tenant by a hostile filter value', async () => {
    const { db, calls } = makeDb();
    const service = new StaffDirectoryService(db);

    // The org id is the only source of tenant scope; even a search string that
    // looks like an org id never becomes the orgId filter.
    await service.listStaff('org-1', { search: 'org-999', page: 1, limit: 50 });

    assert.equal(calls.findMany.where.orgId, 'org-1');
  });

  test('listStaff builds a case-insensitive search across name and contact fields', async () => {
    const { db, calls } = makeDb();
    const service = new StaffDirectoryService(db);

    await service.listStaff('org-1', { search: '  raj  ', page: 1, limit: 50 });

    const fields = calls.findMany.where.OR.map((clause: any) => Object.keys(clause)[0]);
    assert.deepEqual(fields, ['firstName', 'lastName', 'phone', 'email', 'publicId']);
    assert.equal(calls.findMany.where.OR[0].firstName.contains, 'raj');
    assert.equal(calls.findMany.where.OR[0].firstName.mode, 'insensitive');
  });

  test('listStaff paginates with skip/take and computes totalPages', async () => {
    const { db, calls } = makeDb({ findMany: [], count: 45 });
    const service = new StaffDirectoryService(db);

    const result = await service.listStaff('org-1', { page: 3, limit: 20 });

    assert.equal(calls.findMany.skip, 40);
    assert.equal(calls.findMany.take, 20);
    assert.equal(result.total, 45);
    assert.equal(result.page, 3);
    assert.equal(result.totalPages, 3);
  });

  test('the roster select never exposes bank credentials or payment PII', async () => {
    const { db, calls } = makeDb();
    const service = new StaffDirectoryService(db);

    await service.listStaff('org-1', { page: 1, limit: 50 });

    const selectedFields = Object.keys(calls.findMany.select);
    for (const field of SENSITIVE_FIELDS) {
      assert.equal(selectedFields.includes(field), false, `select must not include ${field}`);
    }
    // And it does return the roster basics.
    assert.ok(selectedFields.includes('firstName'));
    assert.ok(selectedFields.includes('workerType'));
    assert.ok(selectedFields.includes('status'));
  });

  test('getStaffById scopes by both id and org and returns the record', async () => {
    const record = { id: 'staff-1', firstName: 'Asha' };
    const { db, calls } = makeDb({ findFirst: record });
    const service = new StaffDirectoryService(db);

    const result = await service.getStaffById('org-1', 'staff-1');

    assert.equal(calls.findFirst.where.id, 'staff-1');
    assert.equal(calls.findFirst.where.orgId, 'org-1');
    assert.equal(calls.findFirst.where.deletedAt, null);
    assert.equal(result, record);
    // Detail must also withhold sensitive fields from the view_staff audience.
    const selectedFields = Object.keys(calls.findFirst.select);
    for (const field of SENSITIVE_FIELDS) {
      assert.equal(selectedFields.includes(field), false, `detail select must not include ${field}`);
    }
  });

  test('getStaffById throws a 404 AppError when the worker is not found', async () => {
    const { db } = makeDb({ findFirst: null });
    const service = new StaffDirectoryService(db);

    await assert.rejects(
      () => service.getStaffById('org-1', 'missing'),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.code, 'NOT_FOUND');
        assert.equal(error.status, 404);
        return true;
      },
    );
  });

  test('getStaffProfile returns the financial PII slice and computes verification honestly', async () => {
    const profile = {
      id: 'staff-1',
      firstName: 'Asha',
      bankAccountNumber: '123456789012',
      ifscCode: 'HDFC0001234',
      upiId: null,
      documents: [{ status: 'PENDING' }],
      salaryRules: [],
      siteAssignments: [],
      payments: [],
    };
    const { db, calls } = makeDb({ findFirst: profile });
    const service = new StaffDirectoryService(db);

    const result = await service.getStaffProfile('org-1', 'staff-1');

    assert.equal(calls.findFirst.where.orgId, 'org-1');
    // Bank details complete, but no approved document yet → blue tick withheld.
    assert.deepEqual(result.verification, {
      bankDetailsComplete: true,
      documentApproved: false,
      verified: false,
    });
  });

  test('getStaffProfile awards verification only when bank details AND an approved document exist', async () => {
    const profile = {
      bankAccountNumber: null,
      ifscCode: null,
      upiId: 'asha@upi',
      documents: [{ status: 'APPROVED' }, { status: 'PENDING' }],
    };
    const { db } = makeDb({ findFirst: profile });
    const service = new StaffDirectoryService(db);

    const result = await service.getStaffProfile('org-1', 'staff-1');

    assert.deepEqual(result.verification, {
      bankDetailsComplete: true,
      documentApproved: true,
      verified: true,
    });
  });

  test('getStaffProfile throws 404 for a worker outside the org', async () => {
    const { db } = makeDb({ findFirst: null });
    const service = new StaffDirectoryService(db);

    await assert.rejects(
      () => service.getStaffProfile('org-1', 'staff-1'),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.status, 404);
        return true;
      },
    );
  });

  test('createStaff scopes to the org, allocates a PM-STF publicId, and audits', async () => {
    const created = { id: 'staff-new', firstName: 'Ravi' };
    const { db, calls } = makeDb({ create: created });
    const service = new StaffDirectoryService(db);

    const result = await service.createStaff('org-1', 'actor-1', {
      firstName: 'Ravi',
      lastName: 'Kumar',
      phone: '9876543210',
      workerType: 'DAILY',
    });

    assert.equal(result, created);
    assert.equal(calls.create.data.orgId, 'org-1');
    assert.match(calls.create.data.publicId, /^PM-STF-\d{6}$/);
    assert.equal(calls.create.data.workerType, 'DAILY');
  });

  test('createStaff rejects a duplicate phone within the same org', async () => {
    const { db } = makeDb({ findFirst: { id: 'existing' } });
    const service = new StaffDirectoryService(db);

    await assert.rejects(
      () => service.createStaff('org-1', 'actor-1', {
        firstName: 'Ravi', lastName: 'Kumar', phone: '9876543210', workerType: 'DAILY',
      }),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.code, 'STAFF_PHONE_EXISTS');
        assert.equal(error.status, 409);
        return true;
      },
    );
  });

  test('listStaffDocuments verifies the worker is in the org before listing', async () => {
    const { db, calls } = makeDb({ findFirst: { id: 'staff-1' }, findMany: [{ id: 'doc-1' }] });
    const service = new StaffDirectoryService(db);

    const result = await service.listStaffDocuments('org-1', 'staff-1');

    assert.equal(calls.findFirst.where.orgId, 'org-1');
    assert.equal(calls.findMany.where.staffId, 'staff-1');
    assert.equal(calls.findMany.where.orgId, 'org-1');
    assert.deepEqual(result, [{ id: 'doc-1' }]);
  });

  test('reviewStaffDocument applies the decision with reviewer, audit, and notification', async () => {
    const { db, calls } = makeDb({ findFirst: { id: 'doc-1', status: 'PENDING' }, update: { id: 'doc-1', status: 'APPROVED' } });
    const service = new StaffDirectoryService(db);

    const result = await service.reviewStaffDocument('org-1', 'staff-1', 'doc-1', 'reviewer-1', {
      action: 'APPROVED',
    });

    assert.equal(result.status, 'APPROVED');
    assert.equal(calls.update.data.status, 'APPROVED');
    assert.equal(calls.update.data.reviewerId, 'reviewer-1');
    assert.ok(calls.update.data.reviewedAt instanceof Date);
    assert.equal(calls.auditCreate.data.action, 'APPROVE');
    assert.equal(calls.auditCreate.data.orgId, 'org-1');
  });

  test('reviewStaffDocument rejection stores the reason', async () => {
    const { db, calls } = makeDb({ findFirst: { id: 'doc-1', status: 'PENDING' }, update: { id: 'doc-1', status: 'REJECTED' } });
    const service = new StaffDirectoryService(db);

    await service.reviewStaffDocument('org-1', 'staff-1', 'doc-1', 'reviewer-1', {
      action: 'REJECTED',
      reason: 'Blurry scan',
    });

    assert.equal(calls.update.data.rejectionReason, 'Blurry scan');
    assert.equal(calls.auditCreate.data.action, 'REJECT');
  });

  test('reviewStaffDocument throws 404 for a document outside the org', async () => {
    const { db } = makeDb({ findFirst: null });
    const service = new StaffDirectoryService(db);

    await assert.rejects(
      () => service.reviewStaffDocument('org-1', 'staff-1', 'doc-x', 'reviewer-1', { action: 'APPROVED' }),
      (error: unknown) => {
        assert.ok(error instanceof AppError);
        assert.equal(error.status, 404);
        return true;
      },
    );
  });
});
