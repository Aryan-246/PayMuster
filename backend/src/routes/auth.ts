import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { isAppError, AppError } from '../lib/app-error.js';
import { authService, type AuthRequestContext } from '../lib/auth-service.js';
import { logger } from '../lib/logger.js';
import { rateLimit } from '../lib/rate-limit.js';
import { requireAuth } from '../middlewares/auth.js';
import { prisma } from '../lib/prisma.js';

const router = Router();

const emailSchema = z.string().trim().email().max(254);
const otpSchema = z.string().regex(/^\d{6}$/, 'Enter the 6-digit code from your email.');

const signupSchema = z.object({
  name: z.string().trim().min(1, 'Enter your full name.').max(100),
  email: emailSchema,
  password: z.string().min(1),
});

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1),
  rememberMe: z.boolean().optional(),
});

const verifyEmailSchema = z.object({
  email: emailSchema,
  otp: otpSchema,
});

const passwordResetSchema = z.object({
  email: emailSchema,
  otp: otpSchema,
  password: z.string().min(1),
});

const googleSchema = z.object({
  idToken: z.string().min(1),
  name: z.string().trim().max(100).optional(),
});

type Endpoint = (request: Request, response: Response) => Promise<void>;

function requestContext(request: Request): AuthRequestContext {
  const userAgent = request.get('user-agent');
  return {
    ipAddress: request.ip,
    userAgent: userAgent || undefined,
  };
}

function otpRequestKey(request: Request): string {
  const requestBody = request.body as { email?: unknown } | undefined;
  const email = typeof requestBody?.email === 'string' ? requestBody.email.trim().toLowerCase() : 'unknown';
  return (request.ip || 'unknown') + ':' + email;
}

function handleEndpointError(request: Request, response: Response, error: unknown): void {
  if (error instanceof z.ZodError) {
    response.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: error.issues[0]?.message || 'Check the information and try again.',
      },
    });
    return;
  }

  if (isAppError(error)) {
    if (error.retryAfterSeconds) {
      response.setHeader('Retry-After', String(error.retryAfterSeconds));
    }

    response.status(error.status).json({
      error: {
        code: error.code,
        message: error.message,
        retryAfterSeconds: error.retryAfterSeconds,
      },
    });
    return;
  }

  logger.error('auth.request_failed', error, {
    method: request.method,
    path: request.path,
    ipAddress: request.ip,
  });
  response.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'We could not complete that request. Please try again.',
    },
  });
}

function endpoint(handler: Endpoint) {
  return async (request: Request, response: Response): Promise<void> => {
    try {
      await handler(request, response);
    } catch (error) {
      handleEndpointError(request, response, error);
    }
  };
}

const signupRateLimit = rateLimit(15 * 60_000, 10, { keyPrefix: 'signup' });
const loginRateLimit = rateLimit(15 * 60_000, 20, { keyPrefix: 'login' });
const otpRequestRateLimit = rateLimit(15 * 60_000, 5, {
  keyPrefix: 'otp-request',
  keyGenerator: otpRequestKey,
});
const otpVerificationRateLimit = rateLimit(15 * 60_000, 10, { keyPrefix: 'otp-verification' });
const sessionRateLimit = rateLimit(15 * 60_000, 10, { keyPrefix: 'session' });

router.post('/signup', signupRateLimit, endpoint(async (request, response) => {
  const data = signupSchema.parse(request.body);
  const result = await authService.register(data, requestContext(request));

  response.status(201).json({
    message: result.verificationEmailSent
      ? 'Account created. Check your email for the verification code.'
      : 'Account created, but we could not send the verification code. Request a new code to continue.',
    user: result.user,
    requiresVerification: true,
    verificationEmailSent: result.verificationEmailSent,
    retryAfterSeconds: result.retryAfterSeconds,
  });
}));

router.post('/resend-verification', otpRequestRateLimit, endpoint(async (request, response) => {
  const { email } = z.object({ email: emailSchema }).parse(request.body);
  const issued = await authService.resendEmailVerification(email);

  response.json({
    message: issued
      ? 'A new verification code has been sent.'
      : 'If an unverified account exists, a verification code has been sent.',
    retryAfterSeconds: issued?.retryAfterSeconds,
  });
}));

const verifyEmail = endpoint(async (request, response) => {
  const data = verifyEmailSchema.parse(request.body);
  const result = await authService.verifyEmail(data.email, data.otp);

  response.json({
    message: result.alreadyVerified ? 'Your email is already verified.' : 'Email verified successfully. You can now sign in.',
  });
});

router.post('/verify-email', otpVerificationRateLimit, verifyEmail);
router.post('/verify-otp', otpVerificationRateLimit, verifyEmail);

router.post('/login', loginRateLimit, endpoint(async (request, response) => {
  const data = loginSchema.parse(request.body);
  const result = await authService.authenticateEmail(
    { ...data, rememberMe: data.rememberMe ?? false },
    requestContext(request),
  );

  response.json({
    message: 'Authenticated',
    ...result,
  });
}));

router.post('/forgot-password', otpRequestRateLimit, endpoint(async (request, response) => {
  const { email } = z.object({ email: emailSchema }).parse(request.body);
  const result = await authService.requestPasswordReset(email, requestContext(request));

  response.json({
    message: 'If the account is eligible, a password reset code has been sent.',
    retryAfterSeconds: result.retryAfterSeconds,
  });
}));

router.post('/reset-password', otpVerificationRateLimit, endpoint(async (request, response) => {
  const data = passwordResetSchema.parse(request.body);
  await authService.resetPassword(data, requestContext(request));

  response.json({ message: 'Password reset successfully. Please sign in with your new password.' });
}));

router.post('/google', loginRateLimit, endpoint(async (request, response) => {
  const data = googleSchema.parse(request.body);
  const result = await authService.authenticateGoogle(data, requestContext(request));

  response.json({
    message: 'Authenticated',
    ...result,
  });
}));

router.post('/refresh', sessionRateLimit, endpoint(async (request, response) => {
  const { refreshToken } = z.object({ refreshToken: z.string().min(1) }).parse(request.body);
  const result = await authService.refreshSession(refreshToken);
  response.json(result);
}));

router.post('/logout', endpoint(async (request, response) => {
  const { refreshToken } = z.object({ refreshToken: z.string().optional() }).parse(request.body ?? {});
  await authService.logout(refreshToken);
  response.json({ message: 'Signed out.' });
}));

router.get('/me', requireAuth, endpoint(async (request, response) => {
  // @ts-expect-error request.user is added by requireAuth middleware
  const userId = request.user?.userId;
  if (!userId) {
    throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      role: true,
      orgId: true,
      firstName: true,
      lastName: true,
    }
  });
  
  if (!user) {
    throw new AppError('NOT_FOUND', 'User not found', 404);
  }

  const joinRequests = await prisma.companyJoinRequest.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' }
  });

  response.json({
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      orgId: user.orgId,
      name: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
    },
    joinRequests
  });
}));

router.post('/account/delete-otp', requireAuth, otpRequestRateLimit, endpoint(async (request, response) => {
  // @ts-expect-error request.user is added by requireAuth middleware
  const userId = request.user?.userId;
  if (!userId) {
    throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
  }

  const { password } = z.object({ password: z.string().min(1) }).parse(request.body);

  await authService.requestDeleteAccountOtp(userId, password, requestContext(request));

  response.json({ message: 'A verification code has been sent.' });
}));

router.post('/account/verify-delete-otp', requireAuth, otpVerificationRateLimit, endpoint(async (request, response) => {
  // @ts-expect-error request.user is added by requireAuth middleware
  const userId = request.user?.userId;
  if (!userId) {
    throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
  }

  const { otp } = z.object({ otp: otpSchema }).parse(request.body);

  await authService.checkDeleteAccountOtp(userId, otp);

  response.json({ message: 'Valid OTP.' });
}));

router.delete('/account', requireAuth, otpVerificationRateLimit, endpoint(async (request, response) => {
  // @ts-expect-error request.user is added by requireAuth middleware
  const userId = request.user?.userId;
  if (!userId) {
    response.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Unauthorized' } });
    return;
  }
  const { otp } = z.object({ otp: otpSchema }).parse(request.body);
  await authService.verifyDeleteAccountOtp(userId, otp);
  await authService.deleteAccount(userId);
  response.json({ message: 'Account permanently deleted.' });
}));

export default router;
