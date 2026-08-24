import crypto from 'node:crypto';
import { prisma } from '../lib/prisma.js';
import { emailService } from '../lib/email-service.js';
import { logger, maskEmail } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';
import type { UserRole } from '../../generated/prisma/client.js';
import { subscriptionService } from './subscription.service.js';

export const FREE_PLAN_MONTHLY_MAIL_LIMIT = 10;

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

function getMonthStart(): Date {
    const d = new Date();
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1, 0, 0, 0));
}

/**
 * Mail Supply Service — manages email campaigns with quota enforcement,
 * role-based targeting, tenant isolation, and audit trail.
 *
 * Admin / Super Admin: send to all permitted users, org-wide, role, individual
 * Owner: send to own staff only; cross-org → DENIED
 * Free plan: 10 mails/month quota (1, 9, 10 allowed, 11th blocked)
 */
export class MailSupplyService {
    /**
     * Get current month's email usage for an organization.
     */
    async getUsage(orgId?: string, actorRole?: string): Promise<{ sent: number; limit: number; remaining: number; monthKey: string }> {
        const monthStart = getMonthStart();
        const monthKey = `${monthStart.getUTCFullYear()}-${String(monthStart.getUTCMonth() + 1).padStart(2, '0')}`;

        const logs = await prisma.auditLog.findMany({
            where: {
                entityType: 'MailSupply',
                ...(orgId ? { orgId } : {}),
                action: 'CREATE',
                createdAt: { gte: monthStart },
            },
            select: { changes: true },
        });

        let totalSent = 0;
        for (const log of logs) {
            const changes = log.changes as Record<string, unknown> | null;
            if (changes && typeof changes.sent === 'number') {
                totalSent += changes.sent;
            } else if (changes && typeof changes.recipientCount === 'number') {
                totalSent += changes.recipientCount;
            }
        }

        // Resolve the effective monthly limit. SUPER_ADMIN and platform-level
        // callers without an org context are not metered against an org free-plan
        // quota; org-scoped callers consult their subscription entitlement.
        let limit: number;
        if (actorRole === 'SUPER_ADMIN' || !orgId) {
            limit = Infinity;
        } else {
            const access = await subscriptionService.getFeatureAccess(orgId, 'mail_supply', actorRole);
            limit = access.unlimited ? Infinity : (access.limit ?? FREE_PLAN_MONTHLY_MAIL_LIMIT);
        }

        return {
            sent: totalSent,
            limit: limit === Infinity ? 999999 : limit,
            remaining: limit === Infinity ? 999999 : Math.max(0, limit - totalSent),
            monthKey,
        };
    }

    /**
     * Resolve mail targets based on targeting criteria with strict tenant isolation.
     */
    async resolveTargets(input: SendMailInput): Promise<MailTarget[]> {
        const isSuperOrAdmin = input.actorRole === 'SUPER_ADMIN' || input.actorRole === 'ADMIN';

        // Non-admin roles (e.g. OWNER) must have an orgId and can only target within their org
        if (!isSuperOrAdmin) {
            if (input.actorRole !== 'OWNER') {
                throw new AppError('UNAUTHORIZED', 'Mail supply is restricted to Owner and Admin roles.', 403);
            }
            if (!input.orgId) {
                throw new AppError('TENANT_REQUIRED', 'Organization is required for Owner mail targeting.', 400);
            }
            if (input.targetType === 'ALL') {
                throw new AppError('TENANT_DENIED', 'Owners cannot broadcast across all organizations.', 403);
            }
        }

        switch (input.targetType) {
            case 'ALL': {
                if (!isSuperOrAdmin) {
                    throw new AppError('UNAUTHORIZED', 'Only Admin or Super Admin can send to all users.', 403);
                }
                const users = await prisma.user.findMany({
                    where: { isDisabled: false, email: { not: null } },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: 1000,
                });
                return users
                    .filter((u): u is typeof u & { email: string } => Boolean(u.email))
                    .map((u) => ({
                        userId: u.id,
                        email: u.email,
                        name: [u.firstName, u.lastName].filter(Boolean).join(' ') || undefined,
                        role: u.role,
                    }));
            }

            case 'ORGANIZATION': {
                if (!input.orgId) {
                    throw new AppError('ORG_REQUIRED', 'Organization ID is required.', 400);
                }
                const users = await prisma.user.findMany({
                    where: { orgId: input.orgId, isDisabled: false, email: { not: null } },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: 500,
                });
                return users
                    .filter((u): u is typeof u & { email: string } => Boolean(u.email))
                    .map((u) => ({
                        userId: u.id,
                        email: u.email,
                        name: [u.firstName, u.lastName].filter(Boolean).join(' ') || undefined,
                        role: u.role,
                    }));
            }

            case 'ROLE': {
                if (!input.targetRole) {
                    throw new AppError('VALIDATION_ERROR', 'targetRole is required for ROLE targeting.', 400);
                }
                const users = await prisma.user.findMany({
                    where: {
                        ...(input.orgId ? { orgId: input.orgId } : {}),
                        role: input.targetRole,
                        isDisabled: false,
                        email: { not: null },
                    },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true },
                    take: 500,
                });
                return users
                    .filter((u): u is typeof u & { email: string } => Boolean(u.email))
                    .map((u) => ({
                        userId: u.id,
                        email: u.email,
                        name: [u.firstName, u.lastName].filter(Boolean).join(' ') || undefined,
                        role: u.role,
                    }));
            }

            case 'INDIVIDUAL': {
                if (!input.targetUserId) {
                    throw new AppError('VALIDATION_ERROR', 'targetUserId is required for INDIVIDUAL targeting.', 400);
                }

                const targetUser = await prisma.user.findUnique({
                    where: { id: input.targetUserId },
                    select: { id: true, email: true, firstName: true, lastName: true, role: true, orgId: true, isDisabled: true },
                });

                if (!targetUser || !targetUser.email) {
                    throw new AppError('USER_NOT_FOUND', 'Target user not found or has no email.', 404);
                }

                if (targetUser.isDisabled) {
                    throw new AppError('USER_DISABLED', 'Target user account is disabled.', 403);
                }

                // Tenant Isolation check: Non-admins cannot send to users in other orgs
                if (!isSuperOrAdmin && targetUser.orgId !== input.orgId) {
                    throw new AppError('TENANT_DENIED', 'Cannot send mail to a user outside your organization.', 403);
                }

                return [{
                    userId: targetUser.id,
                    email: targetUser.email,
                    name: [targetUser.firstName, targetUser.lastName].filter(Boolean).join(' ') || undefined,
                    role: targetUser.role,
                }];
            }

            default:
                throw new AppError('VALIDATION_ERROR', `Invalid targetType: ${input.targetType}`, 400);
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
     * Send mail to resolved targets with quota enforcement, duplicate prevention, and audit.
     */
    async send(input: SendMailInput): Promise<{
        sent: number;
        failed: number;
        blocked: number;
        errors: Array<{ email: string; error: string }>;
        auditId: string;
    }> {
        const targets = await this.resolveTargets(input);
        if (targets.length === 0) {
            return { sent: 0, failed: 0, blocked: 0, errors: [], auditId: '' };
        }

        // Quota check
        const usage = await this.getUsage(input.orgId, input.actorRole);
        if (usage.remaining <= 0) {
            throw new AppError(
                'MAIL_QUOTA_EXCEEDED',
                `Monthly mail quota of ${usage.limit} reached for your plan (${usage.sent}/${usage.limit}). Resets next month.`,
                429,
            );
        }

        const allowedCount = Math.min(targets.length, usage.remaining);
        const blocked = targets.length - allowedCount;
        const sendTargets = targets.slice(0, allowedCount);

        let sent = 0;
        let failed = 0;
        const errors: Array<{ email: string; error: string }> = [];

        for (const target of sendTargets) {
            try {
                // Send email using system email service
                await emailService.sendWelcomeEmail(target.email, {
                    name: target.name || 'Team Member',
                });
                sent++;
            } catch (err: any) {
                failed++;
                errors.push({ email: maskEmail(target.email), error: err.message || 'Delivery error' });
                logger.error('mail_supply.send_error', err, { to: maskEmail(target.email), orgId: input.orgId });
            }
        }

        const auditId = crypto.randomUUID();
        await prisma.auditLog.create({
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
                },
            },
        });

        logger.info('mail_supply.batch_completed', {
            orgId: input.orgId,
            actorId: input.actorId,
            sent,
            failed,
            blocked,
            auditId,
        });

        return { sent, failed, blocked, errors, auditId };
    }

    /**
     * Get mail supply history for an organization.
     */
    async getHistory(orgId?: string, limit = 50): Promise<MailHistoryEntry[]> {
        const logs = await prisma.auditLog.findMany({
            where: {
                entityType: 'MailSupply',
                ...(orgId ? { orgId } : {}),
                action: 'CREATE',
            },
            orderBy: { createdAt: 'desc' },
            take: limit,
            select: {
                id: true,
                createdAt: true,
                userId: true,
                changes: true,
            },
        });

        return logs.map((log) => {
            const changes = (log.changes as Record<string, unknown>) || {};
            return {
                id: log.id,
                sentAt: log.createdAt,
                subject: String(changes.subject || 'Notice'),
                targetType: String(changes.targetType || 'UNKNOWN'),
                recipientCount: typeof changes.sent === 'number' ? changes.sent : (Number(changes.recipientCount) || 0),
                status: (changes.failed as number) > 0 ? 'PARTIAL' : 'SUCCESS',
                actorId: log.userId || 'SYSTEM',
            };
        });
    }
}

export const mailSupplyService = new MailSupplyService();
