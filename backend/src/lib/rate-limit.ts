import type { NextFunction, Request, Response } from 'express';

interface Bucket {
  count: number;
  resetAt: number;
}

interface RateLimitOptions {
  keyPrefix?: string;
  keyGenerator?: (request: Request) => string;
}

const buckets = new Map<string, Bucket>();

function pruneExpiredBuckets(now: number): void {
  if (buckets.size < 1_000) {
    return;
  }

  for (const [key, bucket] of buckets) {
    if (bucket.resetAt <= now) {
      buckets.delete(key);
    }
  }
}

export function rateLimit(
  windowMs = 15 * 60_000,
  maxRequests = 20,
  options: RateLimitOptions = {},
) {
  return (request: Request, response: Response, next: NextFunction): void => {
    const now = Date.now();
    pruneExpiredBuckets(now);

    const clientKey = options.keyGenerator?.(request) || request.ip || 'unknown';
    const key = (options.keyPrefix ?? 'request') + ':' + clientKey;
    const current = buckets.get(key);

    if (!current || now >= current.resetAt) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    if (current.count >= maxRequests) {
      const retryAfterSeconds = Math.max(1, Math.ceil((current.resetAt - now) / 1_000));
      response.setHeader('Retry-After', String(retryAfterSeconds));
      response.status(429).json({
        error: {
          code: 'RATE_LIMITED',
          message: 'Too many requests. Please try again later.',
          retryAfterSeconds,
        },
      });
      return;
    }

    current.count += 1;
    next();
  };
}
