import assert from 'node:assert/strict';
import test, { afterEach } from 'node:test';
import type { Request, Response } from 'express';

import { financialController } from './financial.controller.js';
import { financialIntegrityService } from '../services/financial-integrity.service.js';

const orgId = '11111111-1111-4111-8111-111111111111';
const otherOrgId = '22222222-2222-4222-8222-222222222222';
const actorId = '33333333-3333-4333-8333-333333333333';

type Captured = { status?: number; body?: unknown };

function fakeRes(): { res: Response; captured: Captured } {
  const captured: Captured = {};
  const res = {
    status(code: number) {
      captured.status = code;
      return res;
    },
    json(body: unknown) {
      captured.body = body;
      return res;
    },
  } as unknown as Response;
  return { res, captured };
}

// requireAuth + requireTenant always run before the controller, so the handler
// can rely on both a user and a tenant being present on the context.
function fakeReq(body: unknown, companyId: string = orgId): Request {
  return {
    id: 'req-test',
    context: {
      requestId: 'req-test',
      user: { id: actorId, email: 'accountant@paymuster.com', role: 'ACCOUNTANT', orgId: companyId },
      tenant: { companyId },
    },
    body,
  } as unknown as Request;
}

const delegate = financialIntegrityService as unknown as {
  createAllocation: typeof financialIntegrityService.createAllocation;
  appendExpenseApproval: typeof financialIntegrityService.appendExpenseApproval;
  attachEvidence: typeof financialIntegrityService.attachEvidence;
};
const originalCreate = delegate.createAllocation;
const originalApproval = delegate.appendExpenseApproval;
const originalEvidence = delegate.attachEvidence;

afterEach(() => {
  delegate.createAllocation = originalCreate;
  delegate.appendExpenseApproval = originalApproval;
  delegate.attachEvidence = originalEvidence;
});

test('createAllocation scopes to the tenant org and records the authenticated actor', async () => {
  let received: { orgId: string; createdById: string; input: unknown } | undefined;
  delegate.createAllocation = (async (org: string, createdById: string, input: unknown) => {
    received = { orgId: org, createdById, input };
    return { id: 'alloc-1', orgId: org, amount: (input as { amount: string }).amount } as never;
  }) as typeof financialIntegrityService.createAllocation;
  const { res, captured } = fakeRes();

  const body = { amount: '100.125000', allocationType: 'SITE', expenseId: 'e1', siteId: 's1' };
  await financialController.createAllocation(fakeReq(body), res);

  // Org is taken from the tenant context, not from the (absent) body field.
  assert.equal(received?.orgId, orgId);
  assert.equal(received?.createdById, actorId);
  assert.deepEqual(received?.input, body);
  assert.equal(captured.status, 201);
  assert.equal((captured.body as { success: boolean }).success, true);
  assert.equal((captured.body as { meta: { requestId: string } }).meta.requestId, 'req-test');
});

test('createAllocation cannot be redirected to another tenant via the request body', async () => {
  let received: { orgId: string } | undefined;
  delegate.createAllocation = (async (org: string) => {
    received = { orgId: org };
    return { id: 'alloc-1', orgId: org } as never;
  }) as typeof financialIntegrityService.createAllocation;
  const { res } = fakeRes();

  // A hostile body carries a different orgId; the controller must ignore it.
  await financialController.createAllocation(
    fakeReq({ amount: '10.00', allocationType: 'COMPANY', paymentId: 'p1', orgId: otherOrgId }, orgId),
    res,
  );

  assert.equal(received?.orgId, orgId);
  assert.notEqual(received?.orgId, otherOrgId);
});

test('appendExpenseApproval forwards the tenant org and actor and answers 201', async () => {
  let received: { orgId: string; actorId: string; input: unknown } | undefined;
  delegate.appendExpenseApproval = (async (org: string, actor: string, input: unknown) => {
    received = { orgId: org, actorId: actor, input };
    return { id: 'appr-1', orgId: org, action: (input as { action: string }).action } as never;
  }) as typeof financialIntegrityService.appendExpenseApproval;
  const { res, captured } = fakeRes();

  const body = { expenseId: 'e1', action: 'APPROVED', notes: 'reviewed' };
  await financialController.appendExpenseApproval(fakeReq(body), res);

  assert.deepEqual(received, { orgId, actorId, input: body });
  assert.equal(captured.status, 201);
  assert.equal((captured.body as { data: { action: string } }).data.action, 'APPROVED');
});

test('attachEvidence forwards the tenant org and uploader and answers 201', async () => {
  let received: { orgId: string; uploadedById: string; input: unknown } | undefined;
  delegate.attachEvidence = (async (org: string, uploadedById: string, input: unknown) => {
    received = { orgId: org, uploadedById, input };
    return { id: 'ev-1', orgId: org } as never;
  }) as typeof financialIntegrityService.attachEvidence;
  const { res, captured } = fakeRes();

  const body = {
    paymentId: 'p1',
    storageKey: 'private/receipts/p1.pdf',
    sha256: 'a'.repeat(64),
    mimeType: 'application/pdf',
    byteSize: 1024,
  };
  await financialController.attachEvidence(fakeReq(body), res);

  assert.equal(received?.orgId, orgId);
  assert.equal(received?.uploadedById, actorId);
  assert.deepEqual(received?.input, body);
  assert.equal(captured.status, 201);
});
