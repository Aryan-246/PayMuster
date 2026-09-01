import type { Request, Response } from 'express';
import { AppError } from '../lib/app-error.js';
import { prisma } from '../lib/prisma.js';
import { RolePermissions } from '../lib/permissions.js';
import { streamProvider } from '../providers/realtime.provider.js';

/**
 * Stream token endpoint (blueprint §F/C5): mints a server-signed Stream token
 * for the authenticated user's org channel after real tenant/member
 * authorization. The API secret never leaves the server; the client receives
 * only its user token. When Stream cannot serve a token (creds/SDK), the honest
 * UNAVAILABLE error is surfaced — never a fabricated token.
 */
export async function createRealtimeToken(req: Request, res: Response): Promise<void> {
    const actor = req.context?.user;
    if (!actor) throw new AppError('UNAUTHORIZED', 'Authenticated actor is required.', 401);
    const orgId = req.context?.tenant?.companyId;
    if (!orgId) throw new AppError('TENANT_REQUIRED', 'Company context is required.', 400);

    // Org roster as the channel member set (bounded; orgs are far below the cap).
    const members = await prisma.user.findMany({
        where: {
            orgId,
            deletedAt: null,
            isActive: true,
            isDisabled: false,
        },
        select: { id: true },
        take: 1000,
    });
    const memberIds = members.map((m) => m.id);

    const authorized = await streamProvider.authorize({
        channelId: `org:${orgId}`,
        context: {
            userId: actor.id,
            orgId,
            role: actor.role,
            permissions: RolePermissions[actor.role] ?? [],
        },
        memberIds,
        orgId,
    });
    if (!authorized) {
        throw new AppError('FORBIDDEN', 'Not authorized for this organization channel.', 403);
    }

    const token = await streamProvider.createToken(actor.id);
    if (!token) {
        throw new AppError('REALTIME_UNAVAILABLE', 'Realtime chat/video is currently unavailable.', 503);
    }

    res.status(200).json({
        success: true,
        data: { token, channelId: `org:${orgId}`, expiresInSeconds: 3600 },
        meta: { requestId: req.id },
    });
}
