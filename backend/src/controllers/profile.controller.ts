import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { profileService } from '../services/profile.service.js';

export class ProfileController {
    async getProfile(req: Request, res: Response): Promise<void> {
        const userId = req.context?.user?.id;
        if (!userId) throw new AppError('UNAUTHORIZED', 'Authenticated user is required.', 401);
        const data = await profileService.getProfile(userId);
        res.status(200).json({ success: true, data, meta: { requestId: req.id } });
    }

    async updateProfile(req: Request, res: Response): Promise<void> {
        const userId = req.context?.user?.id;
        if (!userId) throw new AppError('UNAUTHORIZED', 'Authenticated user is required.', 401);
        const data = await profileService.updateProfile(userId, req.body);
        res.status(200).json({ success: true, data, meta: { requestId: req.id } });
    }

    async uploadAvatar(req: Request, res: Response): Promise<void> {
        const userId = req.context?.user?.id;
        if (!userId) throw new AppError('UNAUTHORIZED', 'Authenticated user is required.', 401);
        if (!Buffer.isBuffer(req.body)) {
            throw new AppError('AVATAR_BODY_REQUIRED', 'Upload the avatar as the raw request body.', 400);
        }
        const data = await profileService.uploadAvatar(userId, {
            mimeType: req.get('content-type') ?? '',
            body: req.body,
        });
        res.status(200).json({ success: true, data, meta: { requestId: req.id } });
    }
}

export const profileController = new ProfileController();
