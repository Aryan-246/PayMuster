import type { NextFunction, Request, Response } from 'express';
import { redisProvider } from '../providers/redis.provider.js';

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

/**
 * Rate limiter with a Redis-first, in-memory-fallback strategy (blueprint §R).
 *
 * When Redis is reachable, the window counter lives in the shared store so
 * limits hold across every backend instance. When Redis is unavailable, the
 * previous per-instance in-process Map behavior is preserved — limits stay
 * correct locally and degrade gracefully instead of failing closed.
 */
export function rateLimit(
  windowMs = 15 * 60_000,
  maxRequests = 20,
  options: RateLimitOptions = {},
) {
  const windowSeconds = Math.max(1, Math.ceil(windowMs / 1_000));

  return (request: Request, response: Response, next: NextFunction): void => {
    const clientKey = options.keyGenerator?.(request) || request.ip || 'unknown';
    const key = (options.keyPrefix ?? 'request') + ':' + clientKey;

    void (async () => {
      // Shared (Redis) window first.
      const sharedCount = await redisProvider.incrWithTtl(key, windowSeconds);
      if (sharedCount !== null) {
        if (sharedCount > maxRequests) {
          // Redis TTL gives the exact reset moment only via ttl(); approximate
          // with the window length — safe upper bound for the Retry-After header.
          response.setHeader('Retry-After', String(windowSeconds));
          response.status(429).json({
            error: {
              code: 'RATE_LIMITED',
              message: 'Too many requests. Please try again later.',
              retryAfterSeconds: windowSeconds,
            },
          });
          return;
        }
        next();
        return;
      }

      // In-process fallback (single instance scope).
      const now = Date.now();
      pruneExpiredBuckets(now);

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
    })();
  };
}
