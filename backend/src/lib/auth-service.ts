import { randomUUID } from 'node:crypto';
import jwt, { type JwtPayload, type SignOptions } from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { AppError } from './app-error.js';
import { assertStrongPassword, comparePassword, hashPassword, hashToken } from './auth-utils.js';
import { config } from './config.js';
import { emailService, EmailService, type EmailService as EmailServiceType } from './email-service.js';
import { logger, maskEmail } from './logger.js';
import { maintenanceService } from './maintenance-service.js';
import { otpService, type IssuedOtp, type OtpPurpose, type OtpService } from './otp-service.js';
import { prisma } from './prisma.js';
import { eventBus, Events } from './events.js';

interface UserRecord {
  id: string;
  orgId: string | null;
  status: string;
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
  orgId?: string | null;
  role?: string;
  sessionId?: string;
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
  status: string;
  orgId: string | null;
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
  status: true,
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

const ACCOUNT_IDENTITY_CONFLICT = 'ACCOUNT_IDENTITY_CONFLICT';

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function accountIdentityConflict(): AppError {
  return new AppError(
    ACCOUNT_IDENTITY_CONFLICT,
    'This account requires administrator review before it can be used.',
    409,
  );
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
    status: user.status,
    orgId: user.orgId,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export class AuthService {
  constructor(
    private readonly mailer: typeof emailService = emailService,
    private readonly otpManager: OtpService = otpService,
    private readonly maintenance = maintenanceService,
    private readonly googleClient: Pick<OAuth2Client, 'verifyIdToken'> = new OAuth2Client(config.googleClientId),
    private readonly googleClientId = config.googleClientId,
  ) { }

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

    // Duplicate email check BEFORE transaction. Existing ambiguous data is still
    // a duplicate for signup purposes and must never create another identity.
    let existingUser: UserRecord | null;
    try {
      existingUser = await this.findPublicUserByEmail(email);
    } catch (error) {
      if (error instanceof AppError && error.code === ACCOUNT_IDENTITY_CONFLICT) {
        throw new AppError('EMAIL_ALREADY_REGISTERED', 'An account already exists for this email address.', 409);
      }
      throw error;
    }
    if (existingUser) {
      throw new AppError('EMAIL_ALREADY_REGISTERED', 'An account already exists for this email address.', 409);
    }

    assertStrongPassword(input.password, [email.split('@')[0] || '', input.name]);
    const parts = nameParts(input.name);
    const passwordHash = await hashPassword(input.password);

    // Step 1: Create user in a transaction
    const user = await prisma.$transaction(async (tx) => {
      // The current composite constraint permits duplicate NULL-org emails.
      // Serialize identity creation by normalized email until global uniqueness
      // is enforced by the database migration described in the runbook.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${email}, 0))`;

      const duplicate = await tx.user.findFirst({
        where: { email: { equals: email, mode: 'insensitive' } },
        select: { id: true },
      });
      if (duplicate) {
        throw new AppError('EMAIL_ALREADY_REGISTERED', 'An account already exists for this email address.', 409);
      }

      return tx.user.create({
        data: {
          orgId: null, // Initial users don't belong to any org
          email,
          firstName: parts.firstName,
          lastName: parts.lastName,
          passwordHash,
          role: 'STAFF', // Default role is STAFF
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
    await this.maintenance.assertOperational(user.role);
    if (!user.emailVerified) {
      throw new AppError('EMAIL_NOT_VERIFIED', 'Please verify your email address before signing in.', 403);
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    const session = await this.issueSession(user.id, user.orgId, user.role, input.rememberMe, context);

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
    let user: UserWithPassword | null;

    try {
      user = await this.findCredentialUserByEmail(email);
    } catch (error) {
      if (error instanceof AppError && error.code === ACCOUNT_IDENTITY_CONFLICT) {
        // Preserve the endpoint's anti-enumeration contract and never send an OTP
        // when the email cannot be mapped to exactly one identity.
        return { accepted: true };
      }
      throw error;
    }

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
    if (!this.googleClientId) {
      throw new AppError('GOOGLE_AUTH_UNAVAILABLE', 'Google sign-in is not configured.', 503);
    }

    let payload;
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken: input.idToken,
        audience: this.googleClientId,
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
      await this.maintenance.assertOperational(existingUser.role);
      user = await prisma.user.update({
        where: { id: existingUser.id },
        data: { emailVerified: true, lastLoginAt: new Date() },
        select: publicUserSelect,
      });
    } else {
      // New Google identities have no role that could qualify for emergency
      // access, so maintenance must be checked before entering a write transaction.
      await this.maintenance.assertOperational();
      const suppliedName = (payload.name || input.name || '').trim();
      const parts = nameParts(suppliedName || 'Google User');
      const identity = await prisma.$transaction(async (tx) => {
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${email}, 0))`;

        const matches = await tx.user.findMany({
          where: { email: { equals: email, mode: 'insensitive' } },
          orderBy: { createdAt: 'asc' },
          take: 2,
          select: publicUserSelect,
        });
        this.assertEmailIdentityIsUnambiguous(email, matches);

        if (matches[0]) {
          this.assertUserCanAuthenticate(matches[0]);
          await this.maintenance.assertOperational(matches[0].role);
          return {
            user: await tx.user.update({
              where: { id: matches[0].id },
              data: { emailVerified: true, lastLoginAt: new Date() },
              select: publicUserSelect,
            }),
            created: false,
          };
        }

        // Recheck immediately before creation so no identity is written if
        // maintenance became active while this transaction was waiting.
        await this.maintenance.assertOperational();
        return {
          user: await tx.user.create({
            data: {
              orgId: null,
              email,
              firstName: payload.given_name || parts.firstName,
              lastName: payload.family_name || parts.lastName,
              provider: 'google',
              emailVerified: true,
              role: 'STAFF',
              isActive: true,
            },
            select: publicUserSelect,
          }),
          created: true,
        };
      });
      user = identity.user;
      isNewAccount = identity.created;
    }

    // Keep a defensive final check immediately before session issuance.
    await this.maintenance.assertOperational(user.role);
    const session = await this.issueSession(user.id, user.orgId, user.role, true, context);

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
      where: {
        id: claims.sessionId,
        refreshTokenHash: hashToken(refreshToken),
        revokedAt: null,
      },
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
    if (!user || user.orgId !== session.orgId) {
      throw new AppError('SESSION_INVALID', 'Your session is invalid. Please sign in again.', 401);
    }
    this.assertUserCanAuthenticate(user);
    await this.maintenance.assertOperational(user.role);

    return {
      accessToken: this.createAccessToken(
        claims.userId,
        session.orgId,
        user.role,
        session.id,
      ),
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

  verifyAccessToken(token: string): {
    userId: string;
    orgId: string | null;
    role: string;
    sessionId: string;
  } {
    const claims = this.verifyToken(token, 'access');
    return {
      userId: claims.userId,
      orgId: claims.orgId,
      role: claims.role || 'STAFF',
      sessionId: claims.sessionId,
    };
  }

  async requestDeleteAccountOtp(userId: string, passwordString: string, context?: AuthRequestContext): Promise<IssuedOtp> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status === 'DELETED') {
      throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
    }

    if (user.provider !== 'email') {
      throw new AppError('INVALID_CREDENTIALS', 'Cannot verify password for non-email accounts.', 401);
    }

    if (!user.passwordHash) {
      throw new AppError('INVALID_CREDENTIALS', 'Invalid password.', 401);
    }

    const isValid = await comparePassword(passwordString, user.passwordHash);
    if (!isValid) {
      throw new AppError('INVALID_CREDENTIALS', 'Incorrect password.', 401);
    }

    const issued = await otpService.issue(userId, 'account-deletion');

    // Send email
    await emailService.sendAccountDeletionEmail(user.email!, {
      otp: issued.otp,
    });

    return issued;
  }

  async checkDeleteAccountOtp(userId: string, otp: string): Promise<void> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status === 'DELETED') {
      throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
    }

    await otpService.verify(userId, 'account-deletion', otp);
  }

  async verifyDeleteAccountOtp(userId: string, otp: string): Promise<void> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status === 'DELETED') {
      throw new AppError('UNAUTHORIZED', 'Unauthorized', 401);
    }

    await otpService.consume(userId, 'account-deletion', otp);
  }

  async deleteAccount(userId: string): Promise<void> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return;

    if (user.role === 'SUPER_ADMIN') {
      throw new AppError('ACTION_DENIED', 'Super Admin accounts cannot be permanently deleted.', 403);
    }

    if (user.role === 'OWNER' && user.orgId) {
      throw new AppError(
        'OWNER_ORGANIZATION_REQUIRES_ADMIN_ACTION',
        'An Owner who owns an organization must be removed through an administrator-reviewed process.',
        409,
      );
    }

    await prisma.$transaction(async (tx) => {
      const deletedAt = new Date();

      await tx.session.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: deletedAt },
      });

      const deletedEmail = `deleted-${Date.now()}-${user.email}`;
      await tx.user.update({
        where: { id: userId },
        data: {
          status: 'DELETED',
          email: deletedEmail,
          isActive: false,
          isDisabled: true,
          deletedAt,
          deleteReason: 'User requested account deletion',
        },
      });

      await tx.authOtp.deleteMany({ where: { userId } });
    });

    eventBus.emitEvent(Events.USER_DELETED, { userId });

    // Also log audit action if needed, though audit-listener can handle it if we send it
    eventBus.emitEvent('AuditLog', {
      orgId: user.orgId || null,
      userId: user.id,
      action: 'DELETE',
      entityType: 'User',
      entityId: userId,
      changes: { status: 'DELETED' }
    });

    logger.info('auth.account_soft_deleted', { userId });
  }

  // ── Private helpers ──────────────────────────────────────────────────

  private async findPublicUserByEmail(email: string): Promise<UserRecord | null> {
    const users = await prisma.user.findMany({
      where: { email: { equals: email, mode: 'insensitive' } },
      orderBy: { createdAt: 'asc' },
      take: 2,
      select: publicUserSelect,
    });

    this.assertEmailIdentityIsUnambiguous(email, users);
    return users[0] ?? null;
  }

  private async findCredentialUserByEmail(email: string): Promise<UserWithPassword | null> {
    const users = await prisma.user.findMany({
      where: { email: { equals: email, mode: 'insensitive' } },
      orderBy: { createdAt: 'asc' },
      take: 2,
      select: credentialUserSelect,
    });

    this.assertEmailIdentityIsUnambiguous(email, users);
    return users[0] ?? null;
  }

  private assertEmailIdentityIsUnambiguous(
    email: string,
    users: Array<Pick<UserRecord, 'id' | 'orgId'>>,
  ): void {
    if (users.length <= 1) {
      return;
    }

    const conflict = accountIdentityConflict();
    logger.error('auth.email_identity_conflict', conflict, {
      email: maskEmail(email),
      userIds: users.map((user) => user.id),
      orgIds: users.map((user) => user.orgId),
    });
    throw conflict;
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
  private async rollbackUserCreation(userId: string, orgId: string | null): Promise<void> {
    try {
      // Delete OTPs, then user, then org (respecting FK constraints)
      await prisma.$transaction(async (tx) => {
        await tx.authOtp.deleteMany({ where: { userId } });
        await tx.user.delete({ where: { id: userId } });
        if (orgId) {
          await tx.organization.delete({ where: { id: orgId } });
        }
      });
      logger.info('auth.signup_rollback_completed', { userId, orgId });
    } catch (rollbackError) {
      // Log but don't throw — the original error should propagate
      logger.error('auth.signup_rollback_failed', rollbackError, { userId, orgId });
    }
  }

  private async issueSession(
    userId: string,
    orgId: string | null,
    role: string,
    rememberMe: boolean,
    context: AuthRequestContext,
  ): Promise<AuthSession> {
    const lifetimeMs = rememberMe ? config.rememberMeSessionMs : config.standardSessionMs;
    const sessionId = randomUUID();
    const refreshToken = this.createRefreshToken(userId, orgId, role, sessionId, lifetimeMs);
    const expiresAt = new Date(Date.now() + lifetimeMs);

    await prisma.session.create({
      data: {
        id: sessionId,
        orgId: orgId || null,
        userId,
        refreshTokenHash: hashToken(refreshToken),
        expiresAt,
        deviceInfo: userAgentForStorage(context),
        ipAddress: context.ipAddress || null,
      },
    });

    return {
      accessToken: this.createAccessToken(userId, orgId, role, sessionId),
      refreshToken,
      expiresAt,
    };
  }

  private createAccessToken(
    userId: string,
    orgId: string | null,
    role: string,
    sessionId: string,
  ): string {
    const options: SignOptions = {
      algorithm: 'HS256',
      audience: config.jwtAudience,
      issuer: config.jwtIssuer,
      subject: userId,
      expiresIn: config.jwtAccessExpiresIn as SignOptions['expiresIn'],
    };
    return jwt.sign({ userId, orgId, role, sessionId, type: 'access' }, config.jwtSecret, options);
  }

  private createRefreshToken(
    userId: string,
    orgId: string | null,
    role: string,
    sessionId: string,
    lifetimeMs: number,
  ): string {
    const options: SignOptions = {
      algorithm: 'HS256',
      audience: config.jwtAudience,
      issuer: config.jwtIssuer,
      subject: userId,
      expiresIn: Math.floor(lifetimeMs / 1_000) as SignOptions['expiresIn'],
    };
    return jwt.sign({ userId, orgId, role, sessionId, type: 'refresh' }, config.jwtSecret, options);
  }

  private verifyRefreshToken(token: string): {
    userId: string;
    orgId: string | null;
    role: string;
    sessionId: string;
  } {
    return this.verifyToken(token, 'refresh');
  }

  private verifyToken(
    token: string,
    expectedType: TokenClaims['type'],
  ): { userId: string; orgId: string | null; role: string; sessionId: string } {
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
      typeof claims.sessionId !== 'string' ||
      (typeof claims.orgId !== 'string' && claims.orgId !== null) ||
      claims.sub !== claims.userId
    ) {
      throw new AppError('SESSION_INVALID', 'Your session is invalid. Please sign in again.', 401);
    }

    return {
      userId: claims.userId,
      orgId: claims.orgId,
      role: claims.role || 'WORKER',
      sessionId: claims.sessionId,
    };
  }

  private assertUserCanAuthenticate(user: Pick<UserRecord, 'isDisabled' | 'isActive' | 'status'>): void {
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

    if (['DELETED', 'BLOCKED', 'INACTIVE', 'SUSPENDED', 'REJECTED'].includes(user.status)) {
      throw new AppError(
        'ACCOUNT_UNAVAILABLE',
        `This account is ${user.status.toLowerCase()}.`,
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
