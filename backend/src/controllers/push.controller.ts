import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { pushNotificationService } from '../services/push-notification.service.js';

export class PushController {
    async register(req: Request, res: Response): Promise<void> {
        const user = req.context?.user;
        if (!user?.id) throw new AppError('UNAUTHORIZED', 'Authenticated user is required.', 401);
        const data = await pushNotificationService.registerDevice({
            orgId: user.orgId,
            userId: user.id,
            ...req.body,
        });
        res.status(200).json({ success: true, data, meta: { requestId: req.id } });
    }

    async unregister(req: Request, res: Response): Promise<void> {
        const user = req.context?.user;
        if (!user?.id) throw new AppError('UNAUTHORIZED', 'Authenticated user is required.', 401);
        const data = await pushNotificationService.unregisterDevice(user.id, user.orgId, req.body.token);
        res.status(200).json({ success: true, data, meta: { requestId: req.id } });
    }
}

export const pushController = new PushController();
