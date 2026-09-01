// ADMIN-PHASE TEARDOWN — removes verification fixtures from the dev DB.
//
// Hard-deleted (created purely for this phase's verification):
//   - Pass6 Probe Org cluster (org, probe owner user, subscription,
//     invoice, audit rows, notifications)
//   - Test review PM-REV-000002 + its notifications/audit rows
//
// Soft-deleted (deletedAt set — hidden from every app query, FK integrity
// and cross-phase history preserved; these fixtures are referenced by rows
// from earlier phases, so a hard delete would cascade through Restrict FKs):
//   - phase9.* fixture users + their org
import { prisma } from '../src/lib/prisma.js';

const PROBE_ORG_ID = '7532a20d-9efd-45e8-b482-29a888ab927d';
const PHASE9_ORG_ID = 'cdb04bc6-df0a-4b9a-8a99-9f338b31f5f0';
const steps = [];

async function step(label, fn) {
  const result = await fn();
  steps.push(`${label}: ${result}`);
}

async function main() {
  // ---- Hard teardown: Pass6 Probe Org cluster -----------------------------
  await step('probe org audit logs deleted', () =>
    prisma.auditLog.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org notifications deleted', () =>
    prisma.notification.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org usage records deleted', () =>
    prisma.usageRecord.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org entitlements deleted', () =>
    prisma.entitlement.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org invoices deleted', () =>
    prisma.invoice.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org payment events deleted', () =>
    prisma.paymentEvent.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe org mail dispatches deleted', () =>
    prisma.mailDispatch.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe owner sessions deleted', () =>
    prisma.session.deleteMany({ where: { user: { orgId: PROBE_ORG_ID } } }).then((r) => r.count));
  await step('probe org subscription deleted', () =>
    prisma.subscription.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  await step('probe owner user deleted', () =>
    prisma.user.deleteMany({ where: { orgId: PROBE_ORG_ID } }).then((r) => r.count));
  const probeOrg = await prisma.organization.deleteMany({ where: { id: PROBE_ORG_ID } });
  steps.push(`probe org deleted: ${probeOrg.count}`);

  // ---- Hard teardown: test review + verification notifications ------------
  const review = await prisma.review.findFirst({ where: { publicId: 'PM-REV-000002' } });
  if (review) {
    await step('review audit rows deleted', () =>
      prisma.auditLog.deleteMany({ where: { entityType: 'Review', entityId: review.id } }).then((r) => r.count));
    await prisma.review.delete({ where: { id: review.id } });
    steps.push('test review PM-REV-000002 deleted: 1');
  } else {
    steps.push('test review PM-REV-000002: not found (already gone)');
  }

  // ---- Soft teardown: phase9 fixtures --------------------------------------
  const now = new Date();
  await step('phase9 org soft-deleted', () =>
    prisma.organization.updateMany({ where: { id: PHASE9_ORG_ID }, data: { deletedAt: now } }).then((r) => r.count));
  await step('phase9 org users soft-deleted', () =>
    prisma.user.updateMany({ where: { orgId: PHASE9_ORG_ID }, data: { deletedAt: now } }).then((r) => r.count));
  await step('phase9 superadmin soft-deleted', () =>
    prisma.user.updateMany({ where: { email: 'phase9.superadmin@example.com' }, data: { deletedAt: now } }).then((r) => r.count));
  await step('phase9 sessions deleted', () =>
    prisma.session.deleteMany({ where: { user: { email: { contains: 'phase9' } } } }).then((r) => r.count));

  console.log(steps.join('\n'));

  // ---- Verification ---------------------------------------------------------
  const remaining = {
    probeOrg: await prisma.organization.count({ where: { id: PROBE_ORG_ID } }),
    reviews: await prisma.review.count(),
    phase9ActiveUsers: await prisma.user.count({ where: { email: { contains: 'phase9' }, deletedAt: null } }),
    phase9ActiveOrg: await prisma.organization.count({ where: { id: PHASE9_ORG_ID, deletedAt: null } }),
  };
  console.log('post-teardown state:', JSON.stringify(remaining));
  process.exit(0);
}

main().catch((e) => { console.error('TEARDOWN FAILED:', e.message); process.exit(1); });
