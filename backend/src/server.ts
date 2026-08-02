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

app.listen(config.port, () => {
  logger.info('server.started', { port: config.port, environment: config.nodeEnv });
  void emailService.verifyConnection();
});
