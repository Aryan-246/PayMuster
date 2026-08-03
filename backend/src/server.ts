import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import siteRoutes from './routes/site.routes.js';
import { requestIdMiddleware } from './middlewares/request-id.middleware.js';
import { config } from './lib/config.js';
import { emailService } from './lib/email-service.js';
import { logger } from './lib/logger.js';
import { setupAuditListener } from './lib/audit-listener.js';
import { setupSystemListeners } from './lib/system-listeners.js';

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

app.use('/auth', authRoutes);
app.use('/api/v1/sites', siteRoutes);
app.use('/api/v1/company', companyRoutes);
app.use('/api/v1/admin', adminRoutes);

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
