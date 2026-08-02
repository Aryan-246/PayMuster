import { authService } from '../lib/auth-service.js';
export function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
        res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing bearer token.' } });
        return;
    }
    try {
        const decoded = authService.verifyAccessToken(token);
        req.user = decoded;
        next();
    }
    catch {
        res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token.' } });
    }
}
