import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { aiService } from '../services/ai.service.js';
import type { FoundationAiOperation } from '../schemas/foundation-ai.schema.js';

export class FoundationAiController {
    async process(req: Request, res: Response, operation: FoundationAiOperation): Promise<void> {
        const actor = req.context?.user;
        if (!actor) throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
        // Hard-reject an org-less non-platform actor instead of silently running
        // the AI with zeroed context (blueprint §K — the `__missing_org__`
        // sentinel is defense-in-depth only, never a normal path).
        if (actor.role !== 'SUPER_ADMIN' && !actor.orgId) {
            throw new AppError('TENANT_REQUIRED', 'An organization context is required for AI operations.', 400);
        }
        const result = await aiService.processFoundation(operation.toUpperCase() as 'ANALYZE' | 'SUMMARY' | 'INSIGHTS' | 'QUERY', {
            prompt: req.body.prompt,
            actorId: actor.id,
            role: actor.role,
            orgId: actor.orgId,
            requestId: req.id,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
        });
        res.status(200).json({ success: true, data: result, meta: { requestId: req.id } });
    }
}

export const foundationAiController = new FoundationAiController();
