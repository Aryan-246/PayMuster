import express, { Router, type Request } from 'express';

import { profileController } from '../controllers/profile.controller.js';
import { config } from '../lib/config.js';
import { rateLimit } from '../lib/rate-limit.js';
import { requireAuth } from '../middlewares/auth.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { updateProfileSchema } from '../schemas/profile.schema.js';

const router = Router();
const avatarRateLimit = rateLimit(15 * 60_000, 10, {
    keyPrefix: 'profile-avatar-upload',
    keyGenerator: (request: Request) => request.context?.user?.id ?? request.ip ?? 'unknown',
});
const rawAvatarBody = express.raw({
    type: () => true,
    limit: config.avatarUploadMaxBytes,
});

router.use(requireAuth);
router.get('/', profileController.getProfile.bind(profileController));
router.patch('/', validateRequest(updateProfileSchema), profileController.updateProfile.bind(profileController));
router.post('/avatar', avatarRateLimit, rawAvatarBody, profileController.uploadAvatar.bind(profileController));

export default router;
