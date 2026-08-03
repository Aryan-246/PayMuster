import { AppError } from './app-error.js';
import { config } from './config.js';
import { constantTimeEqual, generateSecureOtp, hashOtp, isOtpExpired } from './auth-utils.js';
import { logger } from './logger.js';
import { prisma } from './prisma.js';
import * as fs from 'fs';

export type OtpPurpose = 'email-verification' | 'password-reset' | 'account-deletion';

export interface IssuedOtp {
  id: string;
  otp: string;
  expiresAt: Date;
  retryAfterSeconds: number;
}

export class OtpService {
  async issue(userId: string, purpose: OtpPurpose): Promise<IssuedOtp> {
    const now = new Date();
    const latest = await prisma.authOtp.findFirst({
      where: { userId, purpose },
      orderBy: { createdAt: 'desc' },
    });

    let resendCount = 0;
    if (latest && !latest.used && !isOtpExpired(latest.expiresAt)) {
      const elapsed = now.getTime() - latest.createdAt.getTime();
      const retryAfterSeconds = Math.ceil((config.otpResendCooldownMs - elapsed) / 1_000);
      if (retryAfterSeconds > 0) {
        throw new AppError(
          'OTP_RESEND_COOLDOWN',
          'Please wait before requesting another code.',
          429,
          { retryAfterSeconds },
        );
      }

      if (latest.resendCount >= config.otpMaxResendAttempts) {
        throw new AppError(
          'OTP_RESEND_LIMIT',
          'You have reached the resend limit. Please wait for the current code to expire.',
          429,
          { retryAfterSeconds: Math.max(1, Math.ceil((latest.expiresAt.getTime() - now.getTime()) / 1_000)) },
        );
      }

      const invalidated = await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { used: true, usedAt: now },
      });

      if (invalidated.count !== 1) {
        throw new AppError('OTP_REQUEST_CONFLICT', 'A verification request is already being processed. Please try again.', 409);
      }

      resendCount = latest.resendCount + 1;
    } else if (latest && !latest.used) {
      await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { used: true, usedAt: now },
      });
    }

    const otp = generateSecureOtp(6);
    fs.writeFileSync('c:/PayMuster/backend/otp.txt', otp);
    const expiresAt = new Date(now.getTime() + config.otpExpiresInMs);
    const record = await prisma.authOtp.create({
      data: {
        userId,
        otpHash: hashOtp(otp, config.otpHashSecret),
        purpose,
        expiresAt,
        resendCount,
      },
    });

    logger.info('otp.issued', { userId, purpose, resendCount, expiresAt: expiresAt.toISOString() });
    return {
      id: record.id,
      otp,
      expiresAt,
      retryAfterSeconds: Math.ceil(config.otpResendCooldownMs / 1_000),
    };
  }

  async verify(userId: string, purpose: OtpPurpose, otp: string): Promise<void> {
    const now = new Date();
    const latest = await prisma.authOtp.findFirst({
      where: { userId, purpose },
      orderBy: { createdAt: 'desc' },
    });

    if (!latest) {
      throw new AppError('OTP_NOT_FOUND', 'No verification code is available. Request a new code and try again.', 400);
    }

    if (latest.used) {
      throw new AppError('OTP_ALREADY_USED', 'This verification code has already been used. Request a new code.', 400);
    }

    if (isOtpExpired(latest.expiresAt)) {
      throw new AppError('OTP_EXPIRED', 'This verification code has expired. Request a new code.', 400);
    }

    if (latest.attemptCount >= config.otpMaxVerificationAttempts) {
      throw new AppError('OTP_ATTEMPT_LIMIT', 'Too many incorrect codes. Request a new code.', 429);
    }

    const matches = constantTimeEqual(latest.otpHash, hashOtp(otp, config.otpHashSecret));
    if (!matches) {
      const attemptCount = latest.attemptCount + 1;
      await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { attemptCount: { increment: 1 } },
      });

      if (attemptCount >= config.otpMaxVerificationAttempts) {
        await prisma.authOtp.updateMany({
          where: { id: latest.id, used: false },
          data: { used: true, usedAt: now },
        });
        throw new AppError('OTP_ATTEMPT_LIMIT', 'Too many incorrect codes. Request a new code.', 429);
      }

      throw new AppError('OTP_INVALID', 'The verification code is incorrect.', 400);
    }
  }

  async consume(userId: string, purpose: OtpPurpose, otp: string): Promise<void> {
    const now = new Date();
    const latest = await prisma.authOtp.findFirst({
      where: { userId, purpose },
      orderBy: { createdAt: 'desc' },
    });

    if (!latest) {
      throw new AppError('OTP_NOT_FOUND', 'No verification code is available. Request a new code and try again.', 400);
    }

    if (latest.used) {
      throw new AppError('OTP_ALREADY_USED', 'This verification code has already been used. Request a new code.', 400);
    }

    if (isOtpExpired(latest.expiresAt)) {
      await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { used: true, usedAt: now },
      });
      throw new AppError('OTP_EXPIRED', 'This verification code has expired. Request a new code.', 400);
    }

    if (latest.attemptCount >= config.otpMaxVerificationAttempts) {
      await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { used: true, usedAt: now },
      });
      throw new AppError('OTP_ATTEMPT_LIMIT', 'Too many incorrect codes. Request a new code.', 429);
    }

    const matches = constantTimeEqual(latest.otpHash, hashOtp(otp, config.otpHashSecret));
    if (!matches) {
      const attemptCount = latest.attemptCount + 1;
      await prisma.authOtp.updateMany({
        where: { id: latest.id, used: false },
        data: { attemptCount: { increment: 1 } },
      });

      if (attemptCount >= config.otpMaxVerificationAttempts) {
        await prisma.authOtp.updateMany({
          where: { id: latest.id, used: false },
          data: { used: true, usedAt: now },
        });
        throw new AppError('OTP_ATTEMPT_LIMIT', 'Too many incorrect codes. Request a new code.', 429);
      }

      throw new AppError('OTP_INVALID', 'The verification code is incorrect.', 400);
    }

    const consumed = await prisma.authOtp.updateMany({
      where: {
        id: latest.id,
        used: false,
        expiresAt: { gt: now },
      },
      data: { used: true, usedAt: now },
    });

    if (consumed.count !== 1) {
      throw new AppError('OTP_ALREADY_USED', 'This verification code has already been used. Request a new code.', 400);
    }

    logger.info('otp.consumed', { userId, purpose });
  }

  async invalidate(otpId: string): Promise<void> {
    await prisma.authOtp.updateMany({
      where: { id: otpId, used: false },
      data: { used: true, usedAt: new Date() },
    });
  }
}

export const otpService = new OtpService();
