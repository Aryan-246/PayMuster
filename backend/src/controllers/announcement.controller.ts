import type { Request, Response } from 'express';

import { announcementInvalidationBroker } from '../lib/announcement-invalidation.js';
import { announcementService } from '../services/announcement.service.js';

interface ListAnnouncementsQuery {
    page: number;
    limit: number;
}

export class AnnouncementController {
    async listMine(req: Request, res: Response) {
        const userId = req.context.user!.id;
        const { page, limit } = res.locals.validatedQuery as ListAnnouncementsQuery;
        const result = await announcementService.listForRecipient(userId, page, limit);

        res.status(200).json({
            success: true,
            data: result.announcements,
            meta: {
                requestId: req.id,
                total: result.total,
                unread: result.unread,
                page: result.page,
                totalPages: result.totalPages,
            },
        });
    }

    async acknowledge(req: Request, res: Response) {
        const userId = req.context.user!.id;
        const { id } = res.locals.validatedParams as { id: string };
        const result = await announcementService.acknowledge(userId, id, {
            requestId: req.id,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
        });

        if (result.changed) {
            announcementInvalidationBroker.publish([userId], {
                reason: 'ACKNOWLEDGED',
                occurredAt: result.acknowledgedAt.toISOString(),
            });
        }

        res.status(200).json({
            success: true,
            data: {
                id: result.id,
                acknowledgedAt: result.acknowledgedAt,
                changed: result.changed,
            },
            meta: { requestId: req.id },
        });
    }

    streamMine(req: Request, res: Response) {
        const userId = req.context.user!.id;

        res.status(200);
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache, no-transform');
        res.setHeader('Connection', 'keep-alive');
        res.flushHeaders();
        res.write('retry: 10000\n\n');
        res.write(`event: ready\ndata: ${JSON.stringify({ connected: true })}\n\n`);

        const unsubscribe = announcementInvalidationBroker.subscribe(userId, (event) => {
            res.write(`event: announcements-invalidated\ndata: ${JSON.stringify(event)}\n\n`);
        });
        const heartbeat = setInterval(() => res.write(': heartbeat\n\n'), 25_000);

        req.on('close', () => {
            clearInterval(heartbeat);
            unsubscribe();
            res.end();
        });
    }
}

export const announcementController = new AnnouncementController();
