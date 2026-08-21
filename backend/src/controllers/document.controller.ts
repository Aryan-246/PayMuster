import type { Request, Response } from 'express';

import { AppError } from '../lib/app-error.js';
import { documentService } from '../services/document.service.js';

export class DocumentController {
    async listMine(req: Request, res: Response): Promise<void> {
        const user = req.context.user!;
        const documents = await documentService.listMine({
            orgId: user.orgId,
            email: user.email,
        });
        res.status(200).json({
            success: true,
            data: documents,
            meta: { requestId: req.id },
        });
    }

    async upload(req: Request, res: Response): Promise<void> {
        if (!Buffer.isBuffer(req.body)) {
            throw new AppError(
                'DOCUMENT_BODY_REQUIRED',
                'Upload the document as the raw request body.',
                400,
            );
        }

        const user = req.context.user!;
        const document = await documentService.upload({
            userId: user.id,
            orgId: user.orgId,
            email: user.email,
            documentType: req.get('x-document-type') ?? '',
            parentDocumentId: req.get('x-parent-document-id') ?? undefined,
            originalFilename: req.get('x-file-name'),
            mimeType: req.get('content-type') ?? '',
            expiryDate: req.get('x-expiry-date'),
            body: req.body,
            requestId: req.id,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
        });
        res.status(201).json({
            success: true,
            data: document,
            meta: { requestId: req.id },
        });
    }

    async createMineViewUrl(req: Request, res: Response): Promise<void> {
        const user = req.context.user!;
        const result = await documentService.createMineViewUrl(
            req.params.id as string,
            { orgId: user.orgId, email: user.email },
        );
        res.status(200).json({
            success: true,
            data: result,
            meta: { requestId: req.id },
        });
    }
}

export const documentController = new DocumentController();
