import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import { config } from './lib/config.js';
import { emailService } from './lib/email-service.js';
import { logger } from './lib/logger.js';

const app = express();

app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(cors({ origin: config.corsOrigins, credentials: true }));
app.use(express.json({ limit: '1mb' }));
app.use((request, response, next) => {
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();

  response.on('finish', () => {
    logger.info('http.request_completed', {
      requestId,
      method: request.method,
      path: request.path,
      statusCode: response.statusCode,
      durationMs: Date.now() - startedAt,
      ipAddress: request.ip,
    });
  });

  next();
});


app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'paymuster-backend' });
});

app.use('/auth', authRoutes);

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
