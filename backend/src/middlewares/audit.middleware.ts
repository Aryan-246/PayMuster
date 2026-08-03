import { Request, Response, NextFunction } from 'express';
import { logger } from '../lib/logger.js';

export const auditMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info(`[API] ${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration}ms`, {
      requestId: req.id,
      userId: req.context?.user?.id,
      tenant: req.context?.tenant,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  });

  next();
};
