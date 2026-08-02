import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import { AppError } from './app-error.js';

export const PASSWORD_MIN_LENGTH = 6;
export const PASSWORD_MAX_LENGTH = 128;

const commonPasswords = new Set([
  'password',
  'password123',
  '123456',
  '12345678',
  'qwerty123',
  'paymuster',
]);

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 12);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateSecureOtp(length = 6): string {
  if (!Number.isInteger(length) || length < 1 || length > 9) {
    throw new Error('OTP length must be an integer between 1 and 9.');
  }

  const upperBound = 10 ** length;
  return crypto.randomInt(0, upperBound).toString().padStart(length, '0');
}

export function hashOtp(otp: string, secret: string): string {
  return crypto.createHmac('sha256', secret).update(otp).digest('hex');
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function constantTimeEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left, 'hex');
  const rightBuffer = Buffer.from(right, 'hex');

  return leftBuffer.length === rightBuffer.length && crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

export function isOtpExpired(expiresAt: Date): boolean {
  return new Date(expiresAt).getTime() <= Date.now();
}

export function validateStrongPassword(password: string, forbiddenValues: string[] = []): string[] {
  const issues: string[] = [];
  const normalizedPassword = password.toLowerCase();

  if (password.length < PASSWORD_MIN_LENGTH) {
    issues.push('Password must be at least ' + PASSWORD_MIN_LENGTH + ' characters.');
  }

  if (password.length > PASSWORD_MAX_LENGTH) {
    issues.push('Password must be no more than ' + PASSWORD_MAX_LENGTH + ' characters.');
  }

  if (commonPasswords.has(normalizedPassword)) {
    issues.push('This password is too common. Choose something more unique.');
  }

  if (forbiddenValues.some((value) => value.length >= 3 && normalizedPassword.includes(value.toLowerCase()))) {
    issues.push('Do not include your name or email in the password.');
  }

  return issues;
}

export function assertStrongPassword(password: string, forbiddenValues: string[] = []): void {
  const issues = validateStrongPassword(password, forbiddenValues);
  if (issues.length > 0) {
    throw new AppError('WEAK_PASSWORD', issues[0], 400);
  }
}

export function generateSecureToken(length = 32): string {
  return crypto.randomBytes(length).toString('hex');
}
