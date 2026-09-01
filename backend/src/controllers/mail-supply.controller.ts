import type { Request, Response, NextFunction } from 'express';
import { mailSupplyService } from '../services/mail-supply.service.js';
import { logger } from '../lib/logger.js';
import { AppError } from '../lib/app-error.js';

/**
 * Mail Supply Controller — endpoints for email campaigns.
 *
 * Authorization is centralized in the route guard: requireAuth → requireTenant
 * (server-authoritative orgId) → requirePermission('manage_mail'). Roles:
 * SUPER_ADMIN / ADMIN / OWNER hold manage_mail; all others are denied 403 by
 * the middleware before reaching the controller.
 */

function getContext(req: Request) {
    const user = req.context?.user;
    if (!user) {
        throw new AppError('UNAUTHENTICATED', 'Authentication required.', 401);
    }
    // Tenant is now established server-side by requireTenant; the client can
    // never choose the orgId. (For SUPER_ADMIN the tenant middleware allows an
    // org-less platform context; mail targeting scope is enforced in the service.)
    const orgId = req.context?.tenant?.companyId || undefined;
    return { userId: user.id, role: user.role, orgId };
}

export async function getMailUsage(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
        const usage = await mailSupplyService.getUsage(ctx.orgId, ctx.role);
        res.json({ success: true, data: usage });
    } catch (err) {
        next(err);
    }
}

export async function previewMail(req: Request, res: Response, next: NextFunction) {
    try {
        const ctx = getContext(req);
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
            // Idempotency-Key from the client header (falls back to a fresh key).
            idempotencyKey: typeof req.headers['idempotency-key'] === 'string'
                ? req.headers['idempotency-key']
                : undefined,
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
        const limit = Math.min(parseInt(String(req.query.limit), 10) || 50, 200);
        const history = await mailSupplyService.getHistory(ctx.orgId, limit);
        res.json({ success: true, data: history });
    } catch (err) {
        next(err);
    }
}
