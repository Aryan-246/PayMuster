import jwt, { type JwtPayload, type SignOptions } from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { AppError } from './app-error.js';
import { assertStrongPassword, comparePassword, hashPassword, hashToken } from './auth-utils.js';
import { config } from './config.js';
import { emailService, EmailService, type EmailService as EmailServiceType } from './email-service.js';
import { logger, maskEmail } from './logger.js';
import { otpService, type IssuedOtp, type OtpPurpose, type OtpService } from './otp-service.js';
import { prisma } from './prisma.js';

interface UserRecord {
  id: string;
  orgId: string;
  email: string | null;
  firstName: string | null;
  lastName: string | null;
  provider: string | null;
  emailVerified: boolean;
  isActive: boolean;
  isDisabled: boolean;
  role: string;
  createdAt: Date;
  updatedAt: Date;
}

interface UserWithPassword extends UserRecord {
  passwordHash: string | null;
}

interface TokenClaims extends JwtPayload {
  userId?: string;
  orgId?: string;
  type?: 'access' | 'refresh';
}

export interface AuthRequestContext {
  ipAddress?: string;
  userAgent?: string;
}

export interface SanitizedUser {
  id: string;
  email: string | null;
  name: string | null;
  provider: string | null;
  emailVerified: boolean;
  isActive: boolean;
  isDisabled: boolean;
  role: string;
  orgId: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
}

export interface AuthenticationResult extends AuthSession {
  user: SanitizedUser;
}

const publicUserSelect = {
  id: true,
  orgId: true,
  email: true,
  firstName: true,
  lastName: true,
  provider: true,
  emailVerified: true,
  isActive: true,
  isDisabled: true,
  role: true,
  createdAt: true,
  updatedAt: true,
} as const;

const credentialUserSelect = {
  ...publicUserSelect,
  passwordHash: true,
} as const;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function displayName(user: Pick<UserRecord, 'firstName' | 'lastName' | 'email'>): string {
  return [user.firstName, user.lastName].filter(Boolean).join(' ').trim() || user.email || 'there';
}

function nameParts(name: string): { firstName: string | null; lastName: string | null } {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] || null,
    lastName: parts.slice(1).join(' ') || null,
  };
}

function userAgentForStorage(context: AuthRequestContext): string {
  return context.userAgent?.slice(0, 255) || 'mobile-app';
}

function buildEmailContext(context: AuthRequestContext): {
  ipAddress?: string;
  browserName?: string;
  deviceName?: string;
  timestamp: string;
} {
  return {
    ipAddress: context.ipAddress,
    browserName: EmailService.parseBrowserName(context.userAgent),
    deviceName: userAgentForStorage(context),
    timestamp: new Date().toISOString(),
  };
}

export function sanitizeUser(user: UserRecord): SanitizedUser {
  return {
    id: user.id,
    email: user.email,
    name: displayName(user),
    provider: user.provider,
    emailVerified: user.emailVerified,
    isActive: user.isActive,
    isDisabled: user.isDisabled,
    role: user.role,
    orgId: user.orgId,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export class AuthService {
  private readonly googleClient = new OAuth2Client(config.googleClientId);

  constructor(
    private readonly mailer: typeof emailService = emailService,
    private readonly otpManager: OtpService = otpService,
  ) {}

  /**
   * Register a new user with atomic transaction.
   * If email delivery fails, the entire signup (user + org + OTP) is rolled back.
   * A user NEVER exists in the database without a successfully sent verification email.
   */
  async register(
    input: { name: string; email: string; password: string },
    context: AuthRequestContext,
  ): Promise<{
    user: SanitizedUser;
    verificationEmailSent: boolean;
    retryAfterSeconds?: number;
  }> {
    const email = normalizeEmail(input.email);

    // Duplicate email check BEFORE transaction
    const existingUser = await this.findPublicUserByEmail(email);
    if (existingUser) {
      throw new AppError('EMAIL_ALREADY_REGISTERED', 'An account already exists for this email address.', 409);
    }

    assertStrongPassword(input.password, [email.split('@')[0] || '', input.name]);
    const parts = nameParts(input.name);
    const passwordHash = await hashPassword(input.password);

    // Step 1: Create user + org in a transaction
    const user = await prisma.$transaction(async (tx) => {
      // Double-check inside transaction to prevent race condition
      const duplicate = await tx.user.findFirst({ where: { email }, select: { id: true } });
      if (duplicate) {
        throw new AppError('EMAIL_ALREADY_REGISTERED', 'An account already exists for this email address.', 409);
      }

      const organization = await tx.organization.create({
        data: { name: (parts.firstName || 'My') + ' Organization' },
      });

      return tx.user.create({
        data: {
          orgId: organization.id,
          email,
          firstName: parts.firstName,
          lastName: parts.lastName,
          passwordHash,
          role: 'OWNER',
          provider: 'email',
          emailVerified: false,
          isActive: true,
        },
        select: publicUserSelect,
      });
    });

    // Step 2: Generate OTP and send email
    // If either fails, roll back the user + org
    let issued: IssuedOtp;
    try {
      issued = await this.otpManager.issue(user.id, 'email-verification');
    } catch (error) {
      // OTP generation failed — clean up user and org
      await this.rollbackUserCreation(user.id, user.orgId);
      throw error;
    }

    try {
      await this.mailer.sendAccountCreatedNotification(email, {
        name: displayName(user),
        otp: issued.otp,
      });
    } catch (error) {
      // Email sending failed — clean up OTP, user, and org
      await this.otpManager.invalidate(issued.id);
      await this.rollbackUserCreation(user.id, user.orgId);
      logger.error('auth.signup_email_failed_rollback', error, {
        userId: user.id,
        email: maskEmail(email),
      });
      throw new AppError(
        'EMAIL_DELIVERY_FAILED',
        'Account creation failed because we could not send the verification email. Please try again.',
        503,
      );
    }

    logger.info('auth.account_created', {
      userId: user.id,
      orgId: user.orgId,
      verificationEmailSent: true,
      ipAddress: context.ipAddress,
    });

    return {
      user: sanitizeUser(user),
      verificationEmailSent: true,
      retryAfterSeconds: issued.retryAfterSeconds,
    };
  }

  async resendEmailVerification(emailInput: string): Promise<IssuedOtp | null> {
    const email = normalizeEmail(emailInput);
    const user = await this.findPublicUserByEmail(email);
    if (!user) {
      return null;
    }

    if (user.emailVerified) {
      throw new AppError('EMAIL_ALREADY_VERIFIED', 'This email address is already verified.', 400);
    }

    return this.deliverOtp(user, 'email-verification');
  }

  async verifyEmail(emailInput: string, otp: string): Promise<{ alreadyVerified: boolean }> {
    const email = normalizeEmail(emailInput);
    const user = await this.findPublicUserByEmail(email);
    if (!user) {
      throw new AppError('OTP_INVALID', 'The verification code is invalid or has expired.', 400);
    }

    if (user.emailVerified) {
      return { alreadyVerified: true };
    }

    await this.otpManager.consume(user.id, 'email-verification', otp);
    const verifiedUser = await prisma.user.update({
      where: { id: user.id },
      data: { emailVerified: true },
      select: publicUserSelect,
    });

    await this.sendNotificationWithoutBlocking(
      'auth.welcome_delivery_failed',
      verifiedUser,
      () => this.mailer.sendWelcomeEmail(email, { name: displayName(verifiedUser) }),
    );
    logger.info('auth.email_verified', { userId: verifiedUser.id });

    return { alreadyVerified: false };
  }

  async authenticateEmail(
    input: { email: string; password: string; rememberMe: boolean },
    context: AuthRequestContext,
  ): Promise<AuthenticationResult> {
    const email = normalizeEmail(input.email);
    const user = await this.findCredentialUserByEmail(email);

    if (!user || !user.passwordHash || !(await comparePassword(input.password, user.passwordHash))) {
      throw new AppError('INVALID_CREDENTIALS', 'Invalid email or password.', 401);
    }

    this.assertUserCanAuthenticate(user);
    if (!user.emailVerified) {
      throw new AppError('EMAIL_NOT_VERIFIED', 'Please verify your email address before signing in.', 403);
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    const session = await this.issueSession(user.id, user.orgId, input.rememberMe, context);

    await this.sendNotificationWithoutBlocking(
      'auth.login_alert_delivery_failed',
      user,
      () =>
        this.mailer.sendLoginNotificationEmail(user.email as string, {
          name: displayName(user),
          ...buildEmailContext(context),
        }),
    );

    logger.info('auth.login_succeeded', {
      userId: user.id,
      method: 'email',
      ipAddress: context.ipAddress,
    });

    return { user: sanitizeUser(user), ...session };
  }

  async requestPasswordReset(emailInput: string, context: AuthRequestContext): Promise<{ accepted: true; retryAfterSeconds?: number }> {
    const email = normalizeEmail(emailInput);
    const user = await this.findCredentialUserByEmail(email);

    if (!user || !user.passwordHash) {
      return { accepted: true };
    }

    const issued = await this.deliverOtp(user, 'password-reset', context);
    logger.info('auth.password_reset_requested', { userId: user.id });
    return { accepted: true, retryAfterSeconds: issued.retryAfterSeconds };
  }

  async resetPassword(input: { email: string; otp: string; password: string }, context: AuthRequestContext): Promise<void> {
    const email = normalizeEmail(input.email);
    const user = await this.findCredentialUserByEmail(email);
    if (!user) {
      throw new AppError('OTP_INVALID', 'The verification code is invalid or has expired.', 400);
    }

    assertStrongPassword(input.password, [email.split('@')[0] || '', displayName(user)]);
    await this.otpManager.consume(user.id, 'password-reset', input.otp);
    const passwordHash = await hashPassword(input.password);
    await prisma.$transaction([
      prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
      prisma.session.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    await this.sendNotificationWithoutBlocking(
      'auth.password_change_delivery_failed',
      user,
      () =>
        this.mailer.sendPasswordChangedEmail(email, {
          name: displayName(user),
          ...buildEmailContext(context),
        }),
    );
    logger.info('auth.password_reset_completed', { userId: user.id });
  }

  async authenticateGoogle(
    input: { idToken: string; name?: string },
    context: AuthRequestContext,
  ): Promise<AuthenticationResult> {
    if (!config.googleClientId) {
      throw new AppError('GOOGLE_AUTH_UNAVAILABLE', 'Google sign-in is not configured.', 503);
    }

    let payload;
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken: input.idToken,
        audience: config.googleClientId,
      });
      payload = ticket.getPayload();
    } catch (error) {
      logger.warn('auth.google_token_rejected', {
        reason: error instanceof Error ? error.name : 'unknown',
      });
      throw new AppError('GOOGLE_AUTH_FAILED', 'Google authentication failed.', 401);
    }

    if (!payload?.email || !payload.email_verified) {
      throw new AppError('GOOGLE_AUTH_FAILED', 'Google authentication failed.', 401);
    }

    const email = normalizeEmail(payload.email);
    const existingUser = await this.findPublicUserByEmail(email);
    let user: UserRecord;
    let isNewAccount = false;

    if (existingUser) {
      this.assertUserCanAuthenticate(existingUser);
      user = await prisma.user.update({
        where: { id: existingUser.id },
        data: { emailVerified: true, lastLoginAt: new Date() },
        select: publicUserSelect,
      });
    } else {
      const suppliedName = (payload.name || input.name || '').trim();
      const parts = nameParts(suppliedName || 'Google User');
      user = await prisma.$transaction(async (tx) => {
        const organization = await tx.organization.create({
          data: { name: (parts.firstName || 'Google') + ' Organization' },
        });

        return tx.user.create({
          data: {
            orgId: organization.id,
            email,
            firstName: payload.given_name || parts.firstName,
            lastName: payload.family_name || parts.lastName,
            provider: 'google',
            emailVerified: true,
            role: 'OWNER',
            isActive: true,
          },
          select: publicUserSelect,
        });
      });
      isNewAccount = true;
    }

    const session = await this.issueSession(user.id, user.orgId, true, context);

    if (isNewAccount) {
      await this.sendNotificationWithoutBlocking(
        'auth.google_welcome_delivery_failed',
        user,
        () => this.mailer.sendWelcomeEmail(email, { name: displayName(user) }),
      );
    }

    // Send Google-specific login notification instead of generic login alert
    await this.sendNotificationWithoutBlocking(
      'auth.google_login_alert_delivery_failed',
      user,
      () =>
        this.mailer.sendGoogleLoginNotificationEmail(user.email as string, {
          name: displayName(user),
          ...buildEmailContext(context),
        }),
    );

    logger.info('auth.login_succeeded', {
      userId: user.id,
      method: 'google',
      isNewAccount,
      ipAddress: context.ipAddress,
    });

    return { user: sanitizeUser(user), ...session };
  }

  async refreshSession(refreshToken: string): Promise<{ accessToken: string; expiresAt: Date }> {
    const claims = this.verifyRefreshToken(refreshToken);
    const session = await prisma.session.findFirst({
      where: { refreshTokenHash: hashToken(refreshToken), revokedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (
      !session ||
      session.expiresAt.getTime() <= Date.now() ||
      session.userId !== claims.userId ||
      session.orgId !== claims.orgId
    ) {
      throw new AppError('SESSION_EXPIRED', 'Your session has expired. Please sign in again.', 401);
    }

    const user = await prisma.user.findUnique({
      where: { id: session.userId },
      select: publicUserSelect,
    });
    if (!user) {
      throw new AppError('SESSION_INVALID', 'Your session is invalid. Please sign in again.', 401);
    }
    this.assertUserCanAuthenticate(user);

    return {
      accessToken: this.createAccessToken(claims.userId, claims.orgId),
      expiresAt: new Date(Date.now() + config.jwtAccessTtlMs),
    };
  }

  async logout(refreshToken?: string): Promise<void> {
    if (!refreshToken) {
      return;
    }

    await prisma.session.updateMany({
      where: { refreshTokenHash: hashToken(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    logger.info('auth.logout_completed');
  }

  verifyAccessToken(token: string): { userId: string; orgId: string } {
    const claims = this.verifyToken(token, 'access');
    return { userId: claims.userId, orgId: claims.orgId };
  }

  async deleteAccount(userId: string): Promise<void> {
    await prisma.$transaction(async (tx) => {
      // 1. Delete exclusively-owned records
      await tx.authOtp.deleteMany({ where: { userId } });
      await tx.session.deleteMany({ where: { userId } });
      await tx.notification.deleteMany({ where: { userId } });
      await tx.syncQueue.deleteMany({ where: { userId } });

      // 2. Delete mandatory operational records that cannot exist without the user
      await tx.paymentApproval.deleteMany({ where: { actorId: userId } });
      await tx.correctionRequest.deleteMany({ where: { requestedById: userId } });

      // 3. Nullify optional references for business records
      await tx.auditLog.updateMany({ where: { userId }, data: { userId: null } });
      await tx.payment.updateMany({ where: { approvedById: userId }, data: { approvedById: null } });
      await tx.payRun.updateMany({ where: { approvedById: userId }, data: { approvedById: null } });
      await tx.attendanceRecord.updateMany({ where: { markedById: userId }, data: { markedById: null } });
      await tx.correctionRequest.updateMany({ where: { resolvedById: userId }, data: { resolvedById: null } });
      await tx.expense.updateMany({ where: { paidById: userId }, data: { paidById: null } });

      // 4. Finally, delete the user
      await tx.user.delete({ where: { id: userId } });
    });
  }

  // ── Private helpers ──────────────────────────────────────────────────

  private async findPublicUserByEmail(email: string): Promise<UserRecord | null> {
    return prisma.user.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
      select: publicUserSelect,
    });
  }

  private async findCredentialUserByEmail(email: string): Promise<UserWithPassword | null> {
    return prisma.user.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
      select: credentialUserSelect,
    });
  }

  private async deliverOtp(
    user: UserRecord,
    purpose: OtpPurpose,
    context?: AuthRequestContext,
  ): Promise<IssuedOtp> {
    if (!user.email) {
      throw new AppError('EMAIL_UNAVAILABLE', 'This account does not have an email address.', 400);
    }

    const issued = await this.otpManager.issue(user.id, purpose);
    try {
      const emailData = {
        name: displayName(user),
        otp: issued.otp,
        ...(context ? buildEmailContext(context) : {}),
      };

      if (purpose === 'email-verification') {
        await this.mailer.sendAccountCreatedNotification(user.email, emailData);
      } else {
        await this.mailer.sendPasswordResetEmail(user.email, emailData);
      }
      return issued;
    } catch (error) {
      await this.otpManager.invalidate(issued.id);
      throw error;
    }
  }

  /**
   * Rolls back a user and their organization created during a failed signup.
   * Called when email delivery fails after user creation.
   */
  private async rollbackUserCreation(userId: string, orgId: string): Promise<void> {
    try {
      // Delete OTPs, then user, then org (respecting FK constraints)
      await prisma.$transaction([
        prisma.authOtp.deleteMany({ where: { userId } }),
        prisma.user.delete({ where: { id: userId } }),
        prisma.organization.delete({ where: { id: orgId } }),
      ]);
      logger.info('auth.signup_rollback_completed', { userId, orgId });
    } catch (rollbackError) {
      // Log but don't throw — the original error should propagate
      logger.error('auth.signup_rollback_failed', rollbackError, { userId, orgId });
    }
  }

  private async issueSession(
    userId: string,
    orgId: string,
    rememberMe: boolean,
    context: AuthRequestContext,
  ): Promise<AuthSession> {
    const lifetimeMs = rememberMe ? config.rememberMeSessionMs : config.standardSessionMs;
    const refreshToken = this.createRefreshToken(userId, orgId, lifetimeMs);
    const expiresAt = new Date(Date.now() + lifetimeMs);

    await prisma.session.create({
      data: {
        orgId,
        userId,
        refreshTokenHash: hashToken(refreshToken),
        expiresAt,
        deviceInfo: userAgentForStorage(context),
        ipAddress: context.ipAddress || null,
      },
    });

    return {
      accessToken: this.createAccessToken(userId, orgId),
      refreshToken,
      expiresAt,
    };
  }

  private createAccessToken(userId: string, orgId: string): string {
    const options: SignOptions = {
      algorithm: 'HS256',
      audience: config.jwtAudience,
      issuer: config.jwtIssuer,
      subject: userId,
      expiresIn: config.jwtAccessExpiresIn as SignOptions['expiresIn'],
    };
    return jwt.sign({ userId, orgId, type: 'access' }, config.jwtSecret, options);
  }

  private createRefreshToken(userId: string, orgId: string, lifetimeMs: number): string {
    const options: SignOptions = {
      algorithm: 'HS256',
      audience: config.jwtAudience,
      issuer: config.jwtIssuer,
      subject: userId,
      expiresIn: Math.floor(lifetimeMs / 1_000) as SignOptions['expiresIn'],
    };
    return jwt.sign({ userId, orgId, type: 'refresh' }, config.jwtSecret, options);
  }

  private verifyRefreshToken(token: string): { userId: string; orgId: string } {
    return this.verifyToken(token, 'refresh');
  }

  private verifyToken(
    token: string,
    expectedType: TokenClaims['type'],
  ): { userId: string; orgId: string } {
    let claims: TokenClaims;
    try {
      claims = jwt.verify(token, config.jwtSecret, {
        algorithms: ['HS256'],
        audience: config.jwtAudience,
        issuer: config.jwtIssuer,
      }) as TokenClaims;
    } catch {
      throw new AppError('SESSION_INVALID', 'Your session is invalid. Please sign in again.', 401);
    }

    if (
      claims.type !== expectedType ||
      typeof claims.userId !== 'string' ||
      typeof claims.orgId !== 'string' ||
      claims.sub !== claims.userId
    ) {
      throw new AppError('SESSION_INVALID', 'Your session is invalid. Please sign in again.', 401);
    }

    return { userId: claims.userId, orgId: claims.orgId };
  }

  private assertUserCanAuthenticate(user: Pick<UserRecord, 'isDisabled' | 'isActive'>): void {
    if (user.isDisabled) {
      throw new AppError(
        'ACCOUNT_DISABLED',
        'This account has been disabled. Contact support for help.',
        403,
      );
    }

    if (!user.isActive) {
      throw new AppError(
        'ACCOUNT_INACTIVE',
        'This account is inactive. Contact support for help.',
        403,
      );
    }
  }

  private async sendNotificationWithoutBlocking(
    event: string,
    user: UserRecord,
    send: () => Promise<void>,
  ): Promise<void> {
    try {
      await send();
    } catch (error) {
      logger.error(event, error, {
        userId: user.id,
        email: user.email ? maskEmail(user.email) : undefined,
      });
    }
  }
}

export const authService = new AuthService();
