import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import siteRoutes from './routes/site.routes.js';
import attendanceRoutes from './routes/attendance.routes.js';
import payrollRoutes from './routes/payroll.routes.js';
import announcementRoutes from './routes/announcement.routes.js';
import profileRoutes from './routes/profile.routes.js';
import { requestIdMiddleware } from './middlewares/request-id.middleware.js';
import { config } from './lib/config.js';
import { emailService } from './lib/email-service.js';
import { logger } from './lib/logger.js';
import { setupAuditListener } from './lib/audit-listener.js';
import { setupSystemListeners } from './lib/system-listeners.js';
import { isAppError, AppError } from './lib/app-error.js';

setupAuditListener();
setupSystemListeners();

const app = express();

app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(cors({ origin: config.corsOrigins, credentials: true }));
app.use(express.json({ limit: '1mb' }));
app.use(requestIdMiddleware);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'paymuster-backend' });
});

import companyRoutes from './routes/company.routes.js';
import adminRoutes from './routes/admin.routes.js';
import documentRoutes from './routes/document.routes.js';

app.use('/auth', authRoutes);
app.use('/api/v1/sites', siteRoutes);
app.use('/api/v1/attendance', attendanceRoutes);
app.use('/api/v1/payroll', payrollRoutes);
app.use('/api/v1/company', companyRoutes);
app.use('/api/v1/documents', documentRoutes);
app.use('/api/v1/announcements', announcementRoutes);
app.use('/api/v1/profile', profileRoutes);
app.use('/api/v1/admin', adminRoutes);

app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  if (res.headersSent) {
    next(err);
    return;
  }

  if (isAppError(err)) {
    if (err.retryAfterSeconds) {
      res.setHeader('Retry-After', String(err.retryAfterSeconds));
    }
    res.status(err.status).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        retryAfterSeconds: err.retryAfterSeconds,
      },
    });
    return;
  }

  if (err?.type === 'entity.too.large') {
    res.status(413).json({
      success: false,
      error: {
        code: req.path.startsWith('/api/v1/documents')
          ? 'DOCUMENT_TOO_LARGE'
          : 'PAYLOAD_TOO_LARGE',
        message: 'The request payload exceeds the allowed size.',
      },
    });
    return;
  }

  if (
    err instanceof SyntaxError &&
    (err as SyntaxError & { type?: string }).type === 'entity.parse.failed'
  ) {
    res.status(400).json({
      success: false,
      error: { code: 'INVALID_JSON', message: 'The request body contains invalid JSON.' },
    });
    return;
  }

  logger.error('server.unhandled_error', err, {
    method: req.method,
    path: req.path,
    requestId: req.id,
  });

  res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'We could not complete that request. Please try again.',
    },
  });
});

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log('--- STARTUP DIAGNOSTICS ---');
  console.log('server.listening:', server.listening);
  console.log('server.address():', server.address());
  console.log('Active handles:', (process as any)._getActiveHandles().length);

  if (server.listening && server.address()) {
    logger.info('server.started', { port: config.port, environment: config.nodeEnv });
  } else {
    logger.error('server.not_listening', { port: config.port });
  }

  void emailService.verifyConnection();
});

server.on('error', (error: NodeJS.ErrnoException) => {
  logger.error('server.failed_to_start', error, { port: config.port });
  console.error(`\n[FATAL] Failed to start server on port ${config.port}`);
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${config.port} is already in use by another process.`);
    console.error(`Please kill the existing process and try again.\n`);
  }
  process.exit(1);
});

export { app };
