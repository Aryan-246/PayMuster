import crypto from 'node:crypto';
import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { config } from '../lib/config.js';
import { prisma } from '../lib/prisma.js';
import { razorpayProvider } from '../providers/razorpay.provider.js';
import { subscriptionService } from '../services/subscription.service.js';

const ACTIVE_SUBSCRIPTION_STATUSES = ['TRIALING', 'ACTIVE', 'PAST_DUE'] as const;

type RazorpayWebhookEntity = {
    id?: unknown;
    order_id?: unknown;
    notes?: unknown;
};

type RazorpayWebhookPayload = {
    id?: unknown;
    event?: unknown;
    payload?: {
        subscription?: { entity?: RazorpayWebhookEntity };
        order?: { entity?: RazorpayWebhookEntity };
        payment?: { entity?: RazorpayWebhookEntity };
    };
};

function stringValue(value: unknown): string | undefined {
    return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function jsonObject(value: unknown): Record<string, unknown> {
    return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

export class BillingController {
    async getSummary(req: Request, res: Response): Promise<void> {
        const orgId = req.context.tenant?.companyId;
        if (!orgId) throw new AppError('TENANT_REQUIRED', 'Company context is required.', 400);

        const subscription = await prisma.subscription.findFirst({
            where: {
                orgId,
                status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                currentPeriodEnd: { gt: new Date() },
            },
            include: {
                plan: true,
                invoices: { orderBy: { createdAt: 'desc' }, take: 1 },
            },
            orderBy: { createdAt: 'desc' },
        });
        if (!subscription) {
            throw new AppError('SUBSCRIPTION_REQUIRED', 'An active subscription is required before checkout.', 402);
        }
        if (!subscription.plan.isActive || subscription.plan.amountMinor <= 0n) {
            throw new AppError('BILLING_PLAN_INVALID', 'The organization billing plan is not available for checkout.', 409);
        }

        const latestInvoice = subscription.invoices[0];
        res.status(200).json({
            success: true,
            data: {
                subscriptionId: subscription.id,
                status: subscription.status,
                currentPeriodStart: subscription.currentPeriodStart,
                currentPeriodEnd: subscription.currentPeriodEnd,
                trialEndsAt: subscription.trialEndsAt,
                cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
                unlimitedAccess: subscription.unlimitedAccess,
                plan: {
                    code: subscription.plan.code,
                    name: subscription.plan.name,
                    description: subscription.plan.description,
                    amountMinor: subscription.plan.amountMinor.toString(),
                    currency: subscription.plan.currency,
                    interval: subscription.plan.interval,
                },
                latestInvoice: latestInvoice ? {
                    id: latestInvoice.id,
                    invoiceNumber: latestInvoice.invoiceNumber,
                    status: latestInvoice.status,
                    totalMinor: latestInvoice.totalMinor.toString(),
                    currency: latestInvoice.currency,
                    paidAt: latestInvoice.paidAt,
                    createdAt: latestInvoice.createdAt,
                } : null,
            },
            meta: { requestId: req.id, mode: config.razorpayMode },
        });
    }

    async createCheckoutOrder(req: Request, res: Response): Promise<void> {
        const user = req.context.user;
        const orgId = req.context.tenant?.companyId;
        if (!user || !orgId) throw new AppError('TENANT_REQUIRED', 'Company context is required.', 400);

        const subscription = await prisma.subscription.findFirst({
            where: {
                orgId,
                status: { in: [...ACTIVE_SUBSCRIPTION_STATUSES] },
                currentPeriodEnd: { gt: new Date() },
            },
            include: { plan: true },
            orderBy: { createdAt: 'desc' },
        });
        if (!subscription) {
            throw new AppError('SUBSCRIPTION_REQUIRED', 'An active subscription is required before checkout.', 402);
        }
        if (!subscription.plan.isActive || subscription.plan.amountMinor <= 0n) {
            throw new AppError('BILLING_PLAN_INVALID', 'The organization billing plan is not available for checkout.', 409);
        }

        const checkoutTimestamp = Date.now();
        const order = await razorpayProvider.createOrder({
            organizationId: orgId,
            userId: user.id,
            amountMinor: subscription.plan.amountMinor,
            currency: subscription.plan.currency,
            receipt: `sub_${subscription.id}_${checkoutTimestamp}`.slice(0, 40),
            notes: {
                organization_id: orgId,
                subscription_id: subscription.id,
                plan_code: subscription.plan.code,
            },
            idempotencyKey: req.header('Idempotency-Key')?.trim() || req.id,
        });
        const invoice = await subscriptionService.createInvoice({
            orgId,
            subscriptionId: subscription.id,
            invoiceNumber: `PM-${checkoutTimestamp}-${subscription.id.slice(0, 8)}`,
            subtotalMinor: order.amountMinor,
            currency: order.currency,
            providerOrderId: order.orderId,
        });

        res.status(201).json({
            success: true,
            data: {
                ...order,
                amountMinor: order.amountMinor.toString(),
                keyId: config.razorpayKeyId,
                subscriptionId: subscription.id,
                invoiceId: invoice.id,
                planCode: subscription.plan.code,
            },
            meta: { requestId: req.id, mode: config.razorpayMode },
        });
    }

    async verifyCheckout(req: Request, res: Response): Promise<void> {
        const orgId = req.context.tenant?.companyId;
        if (!orgId) throw new AppError('TENANT_REQUIRED', 'Company context is required.', 400);

        const orderId = stringValue(req.body.orderId);
        const paymentId = stringValue(req.body.paymentId);
        const signature = stringValue(req.body.signature);
        if (!orderId || !paymentId || !signature) {
            throw new AppError('PAYMENT_VERIFICATION_INVALID', 'Payment verification data is incomplete.', 400);
        }

        const invoice = await prisma.invoice.findFirst({
            where: { providerOrderId: orderId, orgId },
            select: { id: true, subscriptionId: true, status: true },
        });
        if (!invoice) {
            throw new AppError('PAYMENT_ORDER_NOT_FOUND', 'The payment order is not available for this organization.', 404);
        }
        if (!razorpayProvider.verifyCheckoutSignature({ orderId, paymentId, signature })) {
            throw new AppError('PAYMENT_SIGNATURE_INVALID', 'Payment verification failed.', 409);
        }

        res.status(200).json({
            success: true,
            data: {
                verified: true,
                awaitingWebhook: invoice.status !== 'PAID',
                invoiceId: invoice.id,
                subscriptionId: invoice.subscriptionId,
            },
            meta: { requestId: req.id },
        });
    }

    async receiveWebhook(req: Request, res: Response): Promise<void> {
        const signature = req.header('X-Razorpay-Signature')?.trim() ?? '';
        const rawBody = req.rawBody?.toString('utf8') ?? '';
        if (!rawBody || !razorpayProvider.verifyWebhookSignature(rawBody, signature)) {
            throw new AppError('PAYMENT_WEBHOOK_INVALID', 'The payment webhook signature is invalid.', 400);
        }

        let payload: RazorpayWebhookPayload;
        try {
            payload = JSON.parse(rawBody) as RazorpayWebhookPayload;
        } catch {
            throw new AppError('PAYMENT_WEBHOOK_INVALID', 'The payment webhook payload is invalid.', 400);
        }

        const providerEventId = req.header('X-Razorpay-Event-Id')?.trim()
            || stringValue(payload.id)
            || `body_${crypto.createHash('sha256').update(rawBody).digest('hex')}`;
        const eventType = stringValue(payload.event);
        if (!eventType) {
            throw new AppError('PAYMENT_WEBHOOK_INVALID', 'The payment webhook identity is incomplete.', 400);
        }

        const subscriptionEntity = payload.payload?.subscription?.entity;
        const orderEntity = payload.payload?.order?.entity;
        const paymentEntity = payload.payload?.payment?.entity;
        const subscriptionProviderId = stringValue(subscriptionEntity?.id);
        const providerOrderId = stringValue(orderEntity?.id) || stringValue(paymentEntity?.order_id);
        const notes = [
            subscriptionEntity?.notes,
            orderEntity?.notes,
            paymentEntity?.notes,
        ].map(jsonObject).find((candidate) => (
            stringValue(candidate.subscription_id) && stringValue(candidate.organization_id)
        )) ?? {};
        const localSubscriptionId = stringValue(notes.subscription_id);
        const localOrgId = stringValue(notes.organization_id);

        const subscription = subscriptionProviderId
            ? await prisma.subscription.findFirst({
                where: { providerSubscriptionId: subscriptionProviderId },
                select: { id: true, orgId: true },
            })
            : localSubscriptionId && localOrgId
                ? await prisma.subscription.findFirst({
                    where: { id: localSubscriptionId, orgId: localOrgId },
                    select: { id: true, orgId: true },
                })
                : providerOrderId
                    ? (await prisma.invoice.findUnique({
                        where: { providerOrderId },
                        select: { subscription: { select: { id: true, orgId: true } } },
                    }))?.subscription ?? null
                    : null;

        const result = await subscriptionService.processPaymentEvent({
            provider: 'razorpay',
            providerEventId,
            eventType,
            payload: jsonObject(payload),
            orgId: subscription?.orgId,
            subscriptionId: subscription?.id,
            providerOrderId,
        });

        res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
    }
}

export const billingController = new BillingController();
