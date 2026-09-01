import crypto from 'node:crypto';
import { prisma } from '../lib/prisma.js';
import { emailService } from '../lib/email-service.js';
import { logger, maskEmail } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';
import type { UserRole } from '../../generated/prisma/client.js';
import { subscriptionService } from './subscription.service.js';

export const FREE_PLAN_MONTHLY_MAIL_LIMIT = 10;
const MAIL_METRIC = 'mail_supply';
const SEND_TARGET_CAP = 1000;

export interface MailTarget {
    userId: string;
    email: string;
    name?: string;
    role?: string;
}

export interface SendMailInput {
    actorId: string;
    actorRole: string;
    orgId?: string;
    subject: string;
    body: string;
    targetType: 'ALL' | 'ORGANIZATION' | 'ROLE' | 'INDIVIDUAL';
    targetRole?: UserRole;
    targetUserId?: string;
    requestId?: string;
    idempotencyKey?: string;
}

export interface MailHistoryEntry {
    id: string;
    sentAt: Date;
    subject: string;
    targetType: string;
    recipientCount: number;
    status: string;
    actorId: string;
}

export interface MailSendResult {
    sent: number;
    failed: number;
    blocked: number;
    errors: Array<{ email: string; error: string }>;
    dispatchId: string;
    duplicate?: boolean;
}

/** Injectable database surface (defaults to the real Prisma client). */
type MailDb = {
    usageRecord: any;
    mailDispatch: any;
    auditLog: any;
    user: any;
};

/** Injectable mail transport (defaults to the real Nodemailer → Brevo service). */
interface MailTransport {
    send(input: { to: string; subject: string; html: string; text: string; eventId: string }): Promise<'SENT' | 'SKIPPED' | 'UNAVAILABLE'>;
}

/** Injectable entitlement resolver (defaults to the real subscription service). */
interface MailAccessResolver {
    getFeatureAccess(orgId: string, metric: string, actorRole?: string): Promise<{ allowed: boolean; unlimited: boolean; limit: number | null; source: string }>;
}

function getMonthStart(): Date {
    const d = new Date();
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1, 0, 0, 0));
}

function getMonthEnd(periodStart: Date): Date {
    return new Date(Date.UTC(periodStart.getUTCFullYear(), periodStart.getUTCMonth() + 1, 1, 0, 0, 0));
}

function escapeHtml(value: string): string {
    return value
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function isUniqueViolation(error: unknown): boolean {
    return Boolean(error && typeof error === 'object' && 'code' in error && (error as { code?: string }).code === 'P2002');
}

/**
 * Mail Supply Service — email campaigns with server-authoritative quota,
 * role-based targeting, strict tenant isolation, durable idempotency, and audit.
 *
 * Transport: existing Nodemailer → Brevo SMTP pipeline (emailService.send).
 * Composed subject/body are what actually gets delivered — never a template.
 * Metering: UsageRecord rows (metric `mail_supply`) via subscriptionService;
 * quota is reserved atomically BEFORE any send, so retries and concurrent
 * requests can never exceed the cap.
 *
 * SUPER_ADMIN: platform operator, may target all orgs (org-less context).
 * ADMIN: in-org authority only — every target is org-scoped.
 * OWNER: own org only; cross-org targets are DENIED.
 */
export class MailSupplyService {
    private readonly db: MailDb;
    private readonly transport: MailTransport;
    private readonly access: MailAccessResolver;

    constructor(
        db: MailDb = prisma as unknown as MailDb,
        transport: MailTransport = emailService as unknown as MailTransport,
        access: MailAccessResolver = subscriptionService as unknown as MailAccessResolver,
    ) {
        this.db = db;
        this.transport = transport;
        this.access = access;
    }

    /**
     * Get current month's email usage from the UsageRecord meter (blueprint §J).
     */
    async getUsage(orgId?: string, actorRole?: string): Promise<{ sent: number; limit: number; remaining: number; monthKey: string }> {
        const monthStart = getMonthStart();
        const monthKey = `${monthStart.getUTCFullYear()}-${String(monthStart.getUTCMonth() + 1).padStart(2, '0')}`;

        // Platform-level callers are not metered against an org free-plan quota.
        if (!orgId || actorRole === 'SUPER_ADMIN') {
            return { sent: 0, limit: 999999, remaining: 999999, monthKey };
        }

        const usage = await this.db.usageRecord.findUnique({
            where: {
                orgId_metric_periodStart_periodEnd: {
                    orgId,
                    metric: MAIL_METRIC,
                    periodStart: monthStart,
                    periodEnd: getMonthEnd(monthStart),
                },
            },
            select: { quantity: true },
        });
        const sent = Number(usage?.quantity ?? 0);

        const access = await this.access.getFeatureAccess(orgId, MAIL_METRIC, actorRole);
        const limit = access.unlimited ? 999999 : (access.limit ?? FREE_PLAN_MONTHLY_MAIL_LIMIT);

        return {
            sent,
            limit,
            remaining: Math.max(0, limit - sent),
            monthKey,
        };
    }

    /**
     * Resolve mail targets with strict tenant isolation. Non-SUPER_ADMIN actors
     * are always org-scoped: the actor's orgId is the only world they can see.
     */
    async resolveTargets(input: SendMailInput): Promise<MailTarget[]> {
        const isPlatformAdmin = input.actorRole === 'SUPER_ADMIN';

        if (!isPlatformAdmin) {
            if (input.actorRole !== 'OWNER' && input.actorRole !== 'ADMIN') {
                throw new AppError('UNAUTHORIZED', 'Mail supply is restricted to Owner and Admin roles.', 403);
            }
            if (!input.orgId) {
                throw new AppError('TENANT_REQUIRED', 'Organization is required for mail targeting.', 400);
            }
            if (input.targetType === 'ALL') {
                throw new AppError('TENANT_DENIED', 'Owners and Admins cannot broadcast across all organizations.', 403);
            }
        }

        switch (input.targetType) {
            case 'ALL': {
                if (!isPlatformAdmin) {
                    throw new AppError('UNAUTHORIZED', 'Only Super Admin can send to all users.', 403);
                }
                const users = await this.db.user.findMany({
                    where: { isDisabled: false, email: { not: null } },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: SEND_TARGET_CAP,
                });
                return users.map(toMailTarget);
            }

            case 'ORGANIZATION': {
                if (!input.orgId) {
                    throw new AppError('ORG_REQUIRED', 'Organization ID is required.', 400);
                }
                const users = await this.db.user.findMany({
                    where: { orgId: input.orgId, isDisabled: false, email: { not: null } },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: SEND_TARGET_CAP,
                });
                return users.map(toMailTarget);
            }

            case 'ROLE': {
                if (!input.targetRole) {
                    throw new AppError('VALIDATION_ERROR', 'targetRole is required for ROLE targeting.', 400);
                }
                // Non-platform actors are org-scoped even in ROLE targeting.
                const orgFilter = isPlatformAdmin && !input.orgId ? {} : { orgId: input.orgId as string };
                const users = await this.db.user.findMany({
                    where: {
                        ...orgFilter,
                        role: input.targetRole,
                        isDisabled: false,
                        email: { not: null },
                    },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: SEND_TARGET_CAP,
                });
                return users.map(toMailTarget);
            }

            case 'INDIVIDUAL': {
                if (!input.targetUserId) {
                    throw new AppError('VALIDATION_ERROR', 'targetUserId is required for INDIVIDUAL targeting.', 400);
                }
                // Reject malformed ids with a 400 instead of a Prisma P2007 500.
                if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.targetUserId)) {
                    throw new AppError('VALIDATION_ERROR', 'targetUserId must be a valid user id.', 400);
                }

                const targetUser = await this.db.user.findUnique({
                    where: { id: input.targetUserId },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true, orgId: true, isDisabled: true },
                });

                if (!targetUser || !targetUser.email) {
                    throw new AppError('USER_NOT_FOUND', 'Target user not found or has no email.', 404);
                }

                if (targetUser.isDisabled) {
                    throw new AppError('USER_DISABLED', 'Target user account is disabled.', 403);
                }

                // Tenant isolation: non-platform actors can never target outside their org.
                if (!isPlatformAdmin && targetUser.orgId !== input.orgId) {
                    throw new AppError('TENANT_DENIED', 'Cannot send mail to a user outside your organization.', 403);
                }

                return [toMailTarget(targetUser)];
            }

            default:
                throw new AppError('VALIDATION_ERROR', `Invalid targetType: ${input.targetType}`, 400);
        }
    }

    /**
     * Atomically reserve monthly mail quota for `quantity` recipients BEFORE any
     * send (blueprint §J/§R). Works for free orgs (no subscription row: the
     * 10/month baseline) and subscribed orgs alike. The conditional updateMany
     * only fires when the increment stays within the limit, so concurrent
     * requests and multi-instance deployments can never exceed the cap.
     */
    private async reserveQuota(orgId: string, quantity: number, actorRole?: string): Promise<void> {
        const usage = await this.getUsage(orgId, actorRole);
        if (usage.limit >= 999999) return; // unmetered (platform actor / unlimited)
        if (quantity > usage.remaining) {
            throw new AppError(
                'MAIL_QUOTA_EXCEEDED',
                `Monthly mail quota of ${usage.limit} reached for your plan (${usage.sent}/${usage.limit}). Resets next month.`,
                429,
            );
        }

        const periodStart = getMonthStart();
        const periodEnd = getMonthEnd(periodStart);
        const ceiling = usage.limit - quantity;

        const incrementIfWithinLimit = () => this.db.usageRecord.updateMany({
            where: {
                orgId,
                metric: MAIL_METRIC,
                periodStart,
                periodEnd,
                quantity: { lte: ceiling },
            },
            data: { quantity: { increment: quantity } },
        });

        const updated = await incrementIfWithinLimit();
        if (updated.count > 0) return;

        // Row missing → first send this month. Concurrent first-sends collide on
        // the unique (orgId, metric, periodStart, periodEnd) key; the loser of
        // the create retries the conditional increment.
        try {
            await this.db.usageRecord.create({
                data: { orgId, metric: MAIL_METRIC, periodStart, periodEnd, quantity },
            });
            return;
        } catch (error) {
            if (!isUniqueViolation(error)) throw error;
        }

        const retried = await incrementIfWithinLimit();
        if (retried.count === 0) {
            // A concurrent request consumed the remaining quota in between.
            throw new AppError(
                'MAIL_QUOTA_EXCEEDED',
                `Monthly mail quota of ${usage.limit} reached for your plan. Resets next month.`,
                429,
            );
        }
    }

    /**
     * Preview mail targets (count + list) without sending.
     */
    async preview(input: SendMailInput): Promise<{ targets: MailTarget[]; count: number; quotaRemaining: number }> {
        const targets = await this.resolveTargets(input);
        const usage = await this.getUsage(input.orgId, input.actorRole);
        return { targets, count: targets.length, quotaRemaining: usage.remaining };
    }

    /**
     * Send mail to resolved targets with atomic quota reservation, durable
     * idempotency, composed-content delivery, and audit.
     */
    async send(input: SendMailInput): Promise<MailSendResult> {
        // Idempotency fast path: a retried request with the same key returns the
        // original result without re-sending or re-charging quota.
        const key = input.idempotencyKey || crypto.randomUUID();
        const existing = await this.db.mailDispatch.findUnique({ where: { idempotencyKey: key } });
        if (existing) {
            if (existing.status === 'COMPLETED') {
                return {
                    sent: existing.sent,
                    failed: existing.failed,
                    blocked: existing.blocked,
                    errors: [],
                    dispatchId: existing.id,
                    duplicate: true,
                };
            }
            throw new AppError('MAIL_DISPATCH_IN_PROGRESS', 'A send with this idempotency key is already in progress.', 409);
        }

        const targets = await this.resolveTargets(input);
        if (targets.length === 0) {
            return { sent: 0, failed: 0, blocked: 0, errors: [], dispatchId: '' };
        }

        // Reserve quota atomically BEFORE any send (blueprint §J/R): either the
        // whole batch is reserved or nothing is sent (no partial bypass). Mail
        // uses its own reservation because free orgs have no subscription row —
        // the UsageRecord meter is the single source of truth either way.
        if (input.orgId) {
            await this.reserveQuota(input.orgId, targets.length, input.actorRole);
        }

        // Record the dispatch intent (durable anchor) BEFORE sending.
        const dispatch = await this.db.mailDispatch.create({
            data: {
                orgId: input.orgId ?? null,
                idempotencyKey: key,
                status: 'PENDING',
                subject: input.subject,
                targetType: input.targetType,
                targetRole: input.targetRole ?? null,
                targetUserId: input.targetUserId ?? null,
                recipientCount: targets.length,
                actorId: input.actorId,
            },
        });

        let sent = 0;
        let failed = 0;
        const errors: Array<{ email: string; error: string }> = [];

        for (const target of targets) {
            // emailService.send() never throws — it retries internally and returns
            // a tri-state result, so failures are counted from the return value.
            let outcome: 'SENT' | 'SKIPPED' | 'UNAVAILABLE';
            try {
                outcome = await this.transport.send({
                    to: target.email,
                    subject: input.subject,
                    // Composed body IS the payload — never a substituted template.
                    html: wrapBodyHtml(input.body),
                    text: input.body,
                    eventId: `${key}:${target.userId}`,
                });
            } catch (err: any) {
                outcome = 'UNAVAILABLE';
                logger.error('mail_supply.send_error', err, { to: maskEmail(target.email), orgId: input.orgId });
            }
            if (outcome === 'SENT') {
                sent++;
            } else {
                failed++;
                errors.push({
                    email: maskEmail(target.email),
                    error: outcome === 'SKIPPED' ? 'SMTP_NOT_CONFIGURED' : 'DELIVERY_UNAVAILABLE',
                });
            }
        }
        // Quota was reserved atomically for every target before any send, so a
        // fully-reserved batch is always attempted; delivery failures are the
        // only source of non-delivery.
        const blocked = 0;

        await this.db.mailDispatch.update({
            where: { id: dispatch.id },
            data: { sent, failed, blocked, status: 'COMPLETED' },
        });

        const auditId = crypto.randomUUID();
        await this.db.auditLog.create({
            data: {
                id: auditId,
                entityType: 'MailSupply',
                entityId: auditId,
                action: 'CREATE',
                userId: input.actorId,
                orgId: input.orgId || null,
                changes: {
                    subject: input.subject,
                    targetType: input.targetType,
                    targetRole: input.targetRole || null,
                    targetUserId: input.targetUserId || null,
                    recipientCount: targets.length,
                    sent,
                    failed,
                    blocked,
                    dispatchId: dispatch.id,
                },
            },
        });

        logger.info('mail_supply.batch_completed', {
            orgId: input.orgId,
            actorId: input.actorId,
            sent,
            failed,
            blocked,
            dispatchId: dispatch.id,
        });

        return { sent, failed, blocked, errors, dispatchId: dispatch.id };
    }

    /**
     * Get mail supply history for an organization (from MailDispatch rows).
     */
    async getHistory(orgId?: string, limit = 50): Promise<MailHistoryEntry[]> {
        const dispatches = await this.db.mailDispatch.findMany({
            where: orgId ? { orgId } : {},
            orderBy: { createdAt: 'desc' },
            take: limit,
            select: {
                id: true,
                createdAt: true,
                subject: true,
                targetType: true,
                sent: true,
                failed: true,
                actorId: true,
                recipientCount: true,
            },
        });

        return dispatches.map((d: {
            id: string;
            createdAt: Date;
            subject: string;
            targetType: string;
            sent: number;
            failed: number;
            actorId: string | null;
            recipientCount: number;
        }) => ({
            id: d.id,
            sentAt: d.createdAt,
            subject: d.subject,
            targetType: d.targetType,
            recipientCount: d.recipientCount,
            status: d.failed > 0 ? 'PARTIAL' : 'SUCCESS',
            actorId: d.actorId || 'SYSTEM',
        }));
    }
}

function toMailTarget(u: { id: string; email: string | null; firstName: string | null; lastName: string | null; role: string }) {
    return {
        userId: u.id,
        email: u.email as string,
        name: [u.firstName, u.lastName].filter(Boolean).join(' ') || undefined,
        role: u.role,
    };
}

function wrapBodyHtml(body: string): string {
    return `<div style="font-family:'Segoe UI',Inter,Arial,sans-serif;font-size:15px;line-height:1.65;color:#CBD5E1;">${escapeHtml(body).replace(/\n/g, '<br>')}</div>`;
}

export const mailSupplyService = new MailSupplyService();
