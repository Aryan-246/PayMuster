import { Router } from 'express';

import { foundationAiController } from '../controllers/foundation-ai.controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { requirePermission } from '../middlewares/permission.middleware.js';
import { validateRequest } from '../middlewares/validation.middleware.js';
import { foundationAiRequestSchema } from '../schemas/foundation-ai.schema.js';

const router = Router();
router.use(requireAuth);
router.use(requirePermission('use_ai'));
router.post('/analyze', validateRequest(foundationAiRequestSchema), (req, res) => foundationAiController.process(req, res, 'analyze'));
router.post('/summary', validateRequest(foundationAiRequestSchema), (req, res) => foundationAiController.process(req, res, 'summary'));
router.post('/insights', validateRequest(foundationAiRequestSchema), (req, res) => foundationAiController.process(req, res, 'insights'));
router.post('/query', validateRequest(foundationAiRequestSchema), (req, res) => foundationAiController.process(req, res, 'query'));

export default router;
