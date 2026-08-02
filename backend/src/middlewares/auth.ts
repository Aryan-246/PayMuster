import type { Request, Response, NextFunction } from 'express';
import { authService } from '../lib/auth-service.js';

export interface AuthenticatedRequest extends Request {
  user?: {
    userId: string;
    orgId: string;
    role?: string;
  };
}

export function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction) {
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
  } catch {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token.' } });
  }
}
