import type { Request, Response } from 'express';

import { notificationService } from '../services/notification.service.js';

interface ListNotificationsQuery {
    page: number;
    limit: number;
    unreadOnly: boolean;
}

export class NotificationController {
    async listMine(req: Request, res: Response) {
        const userId = req.context.user!.id;
        const orgId = req.context.tenant!.companyId!;
        const { page, limit, unreadOnly } = res.locals.validatedQuery as ListNotificationsQuery;

        const result = await notificationService.listForUser(userId, orgId, { page, limit, unreadOnly });

        res.status(200).json({
            success: true,
            data: result.notifications,
            meta: {
                requestId: req.id,
                total: result.total,
                page: result.page,
                totalPages: result.totalPages,
                unread: result.unread,
            },
        });
    }

    async markRead(req: Request, res: Response) {
        const userId = req.context.user!.id;
        const orgId = req.context.tenant!.companyId!;
        const { id } = res.locals.validatedParams as { id: string };

        const result = await notificationService.markRead(userId, orgId, id);

        res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
    }

    async markAllRead(req: Request, res: Response) {
        const userId = req.context.user!.id;
        const orgId = req.context.tenant!.companyId!;

        const result = await notificationService.markAllRead(userId, orgId);

        res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
    }
}

export const notificationController = new NotificationController();
