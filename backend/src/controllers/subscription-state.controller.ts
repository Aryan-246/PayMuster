import type { Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { subscriptionService } from '../services/subscription.service.js';
import { RolePermissions } from '../lib/permissions.js';

/**
 * Subscription state controller — honest, read-only view for the tenant UI.
 * Never throws for lack of a subscription: the state IS the answer.
 * The raw global-switch value is exposed only to roles that hold
 * manage_system / manage_billing; ordinary users see their effective access
 * without platform admin controls (blueprint §I / §W).
 */
export async function getSubscriptionState(req: Request, res: Response): Promise<void> {
    const orgId = req.context?.tenant?.companyId;
    if (!orgId) throw new AppError('TENANT_REQUIRED', 'Company context is required.', 400);

    const actor = req.context?.user;
    if (!actor) throw new AppError('UNAUTHORIZED', 'Authentication required.', 401);

    const [enforcementEnabled, subscription] = await Promise.all([
        subscriptionService.getGlobalSubscriptionSwitch(),
        prisma.subscription.findFirst({
            where: { orgId },
            orderBy: { createdAt: 'desc' },
            include: { plan: { select: { code: true, name: true, interval: true } } },
        }),
    ]);

    const rolePermissions = RolePermissions[actor.role] ?? [];
    const maySeeSwitch = rolePermissions.includes('manage_system') || rolePermissions.includes('manage_billing');

    // Effective feature access for a representative metered feature tells the UI
    // whether entitlement enforcement is currently biting for this org.
    const mailAccess = await subscriptionService.getFeatureAccess(orgId, 'mail_supply', actor.role);

    res.status(200).json({
        success: true,
        data: {
            subscription: subscription ? {
                id: subscription.id,
                status: subscription.status,
                currentPeriodStart: subscription.currentPeriodStart,
                currentPeriodEnd: subscription.currentPeriodEnd,
                trialEndsAt: subscription.trialEndsAt,
                cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
                unlimitedAccess: subscription.unlimitedAccess,
                plan: subscription.plan,
            } : null,
            effectiveAccess: {
                allowed: mailAccess.allowed,
                unlimited: mailAccess.unlimited,
                limit: mailAccess.limit,
                source: mailAccess.source,
            },
            // Only billing-capable operators learn the platform switch state.
            ...(maySeeSwitch ? { enforcementEnabled } : {}),
        },
        meta: { requestId: req.id },
    });
}
