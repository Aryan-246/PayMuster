import { Router } from 'express';

import { pushController } from '../controllers/push.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { registerDeviceSchema, unregisterDeviceSchema } from '../schemas/push.schema.js';

const router = Router();
router.use(requireAuth);
router.post('/devices', validateRequest(registerDeviceSchema), pushController.register.bind(pushController));
router.delete('/devices', validateRequest(unregisterDeviceSchema), pushController.unregister.bind(pushController));

export default router;
