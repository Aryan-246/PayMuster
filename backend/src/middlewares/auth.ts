import type { Request, Response, NextFunction } from 'express';
import { authService } from '../lib/auth-service.js';

export interface AuthenticatedRequest extends Request {
  user?: {
    userId: string;
    orgId: string | null;
    role?: string;
  };
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing bearer token.' } });
    return;
  }

  try {
    const decoded = authService.verifyAccessToken(token);
    (req as any).context = (req as any).context || { requestId: (req as any).id };
    (req as any).context.user = {
      id: decoded.userId,
      email: (decoded as any).email || '',
      role: (decoded as any).role || 'WORKER'
    };
    
    // Set req.user to match AuthenticatedRequest
    (req as AuthenticatedRequest).user = {
      userId: decoded.userId,
      orgId: decoded.orgId,
      role: (decoded as any).role || 'WORKER'
    };
    next();
  } catch {
    res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token.' } });
  }
}
