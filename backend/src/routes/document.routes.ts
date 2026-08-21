import express, { Router, type Request } from 'express';

import { documentController } from '../controllers/document.controller.js';
import { config } from '../lib/config.js';
import { rateLimit } from '../lib/rate-limit.js';
import { requireAuth } from '../middlewares/auth.js';

const router = Router();
const uploadRateLimit = rateLimit(15 * 60_000, 20, {
    keyPrefix: 'document-upload',
    keyGenerator: (request: Request) => request.context?.user?.id ?? request.ip ?? 'unknown',
});
const rawDocumentBody = express.raw({
    type: () => true,
    limit: config.documentUploadMaxBytes,
});

router.use(requireAuth);
router.get('/', documentController.listMine.bind(documentController));
router.post(
    '/',
    uploadRateLimit,
    rawDocumentBody,
    documentController.upload.bind(documentController),
);
router.post('/:id/view', documentController.createMineViewUrl.bind(documentController));

export default router;
