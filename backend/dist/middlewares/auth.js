import { authService } from '../lib/auth-service.js';
import { prisma } from '../lib/prisma.js';
import { maintenanceService } from '../lib/maintenance-service.js';
export async function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
        res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing bearer token.' } });
        return;
    }
    let decoded;
    try {
        decoded = authService.verifyAccessToken(token);
    }
    catch {
        res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token.' } });
        return;
    }
    try {
        const [user, session] = await Promise.all([
            prisma.user.findUnique({
                where: { id: decoded.userId },
                select: {
                    id: true,
                    orgId: true,
                    email: true,
                    role: true,
                    status: true,
                    isActive: true,
                    isDisabled: true,
                },
            }),
            prisma.session.findFirst({
                where: {
                    id: decoded.sessionId,
                    userId: decoded.userId,
                    revokedAt: null,
                    expiresAt: { gt: new Date() },
                },
                select: {
                    id: true,
                    orgId: true,
                },
            }),
        ]);
        if (!user ||
            !session ||
            decoded.orgId !== session.orgId ||
            user.orgId !== session.orgId) {
            res.status(401).json({ success: false, error: { code: 'SESSION_INVALID', message: 'Your session is invalid. Please sign in again.' } });
            return;
        }
        if (user.isDisabled ||
            !user.isActive ||
            ['DELETED', 'BLOCKED', 'INACTIVE', 'SUSPENDED', 'REJECTED'].includes(user.status)) {
            res.status(403).json({ success: false, error: { code: 'ACCOUNT_UNAVAILABLE', message: 'This account is not available.' } });
            return;
        }
        req.context = req.context || { requestId: req.id };
        req.context.user = {
            id: user.id,
            email: user.email || '',
            role: user.role,
            orgId: user.orgId,
        };
        req.user = {
            userId: user.id,
            orgId: user.orgId,
            role: user.role,
        };
        try {
            await maintenanceService.assertOperational(user.role);
        }
        catch (error) {
            const maintenanceError = error;
            res.status(503).json({
                success: false,
                error: {
                    code: maintenanceError.code || 'MAINTENANCE_STATE_UNKNOWN',
                    message: maintenanceError.message || 'PayMuster availability could not be verified.',
                },
            });
            return;
        }
        next();
    }
    catch (error) {
        next(error);
    }
}
