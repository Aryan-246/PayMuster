import type { Request, Response, NextFunction } from 'express';
import { mailSupplyService } from '../services/mail-supply.service.js';
import { logger } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';

/**
 * Mail Supply Controller — RBAC-protected endpoints for email sending.
 *
 * ADMIN / SUPER_ADMIN → full access (all targets)
 * OWNER → own staff only
 * Other roles → DENIED
 */

function getContext(req: Request) {
    const user = req.context?.user;
    if (!user) {
        throw new AppError('UNAUTHENTICATED', 'Authentication required.', 401);
    }
    const orgId = req.context?.tenant?.companyId || user.orgId || undefined;
    return { userId: user.id, role: user.role, orgId };
}

function assertMailRole(role: string): void {
    const allowed = ['ADMIN', 'SUPER_ADMIN', 'OWNER'];
    if (!allowed.includes(role)) {
        throw new AppError('FORBIDDEN', 'Mail supply is restricted to Owner and Admin roles.', 403);
    }
}

export async function getMailUsage(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
        assertMailRole(ctx.role);

        const usage = await mailSupplyService.getUsage(ctx.orgId, ctx.role);
        res.json({ success: true, data: usage });
    } catch (err) {
        next(err);
    }
}

export async function previewMail(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
        assertMailRole(ctx.role);

        const { subject, body, targetType, targetRole, targetUserId } = req.body;
        if (!subject || !body || !targetType) {
            throw new AppError('VALIDATION_ERROR', 'subject, body, and targetType are required.', 400);
        }

        const result = await mailSupplyService.preview({
            actorId: ctx.userId,
            actorRole: ctx.role,
            orgId: ctx.orgId,
            subject,
            body,
            targetType,
            targetRole,
            targetUserId,
        });

        res.json({ success: true, data: result });
    } catch (err) {
        next(err);
    }
}

export async function sendMail(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
        assertMailRole(ctx.role);

        const { subject, body, targetType, targetRole, targetUserId } = req.body;
        if (!subject || !body || !targetType) {
            throw new AppError('VALIDATION_ERROR', 'subject, body, and targetType are required.', 400);
        }

        const result = await mailSupplyService.send({
            actorId: ctx.userId,
            actorRole: ctx.role,
            orgId: ctx.orgId,
            subject,
            body,
            targetType,
            targetRole,
            targetUserId,
            requestId: req.id,
        });

        logger.info('mail_supply.api_send', {
            actorId: ctx.userId,
            role: ctx.role,
            orgId: ctx.orgId,
            sent: result.sent,
            failed: result.failed,
            blocked: result.blocked,
        });

        res.json({ success: true, data: result });
    } catch (err) {
        next(err);
    }
}

export async function getMailHistory(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
        assertMailRole(ctx.role);

        const limit = Math.min(parseInt(String(req.query.limit), 10) || 50, 200);
        const history = await mailSupplyService.getHistory(ctx.orgId, limit);
        res.json({ success: true, data: history });
    } catch (err) {
        next(err);
    }
}
