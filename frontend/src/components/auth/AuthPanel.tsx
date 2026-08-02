import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ApiError, postJson } from '../../lib/api';
import {
  persistSession,
  type AuthSession,
  type AuthenticatedUser,
} from '../../lib/auth-session';

type AuthView = 'login' | 'signup' | 'verify-email' | 'forgot-password' | 'reset-password';

interface AuthResponse {
  user: AuthenticatedUser;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

interface OtpResponse {
  message: string;
  retryAfterSeconds?: number;
}

interface GoogleIdentityApi {
  accounts: {
    id: {
      initialize: (config: {
        client_id: string;
        callback: (response: { credential?: string }) => void;
      }) => void;
      renderButton: (element: HTMLElement, options: Record<string, unknown>) => void;
    };
  };
}

declare global {
  interface Window {
    google?: GoogleIdentityApi;
  }
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function passwordChecks(password: string) {
  return [
    { label: '12+ characters', passed: password.length >= 12 },
    { label: 'Uppercase letter', passed: /[A-Z]/.test(password) },
    { label: 'Lowercase letter', passed: /[a-z]/.test(password) },
    { label: 'Number', passed: /\d/.test(password) },
    { label: 'Symbol', passed: /[^A-Za-z0-9\s]/.test(password) },
  ];
}

function countdownLabel(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return String(minutes).padStart(2, '0') + ':' + String(remainingSeconds).padStart(2, '0');
}

function GoogleSignInButton({ disabled, onCredential }: { disabled: boolean; onCredential: (credential: string) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const credentialHandlerRef = useRef(onCredential);
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

  useEffect(() => {
    credentialHandlerRef.current = onCredential;
  }, [onCredential]);

  useEffect(() => {
    if (!clientId || !containerRef.current) {
      return;
    }

    let disposed = false;
    const renderButton = () => {
      const googleIdentity = window.google?.accounts.id;
      if (disposed || !googleIdentity || !containerRef.current) {
        return;
      }

      googleIdentity.initialize({
        client_id: clientId,
        callback: (response) => {
          if (response.credential) {
            credentialHandlerRef.current(response.credential);
          }
        },
      });
      containerRef.current.innerHTML = '';
      googleIdentity.renderButton(containerRef.current, {
        type: 'standard',
        theme: 'outline',
        size: 'large',
        text: 'continue_with',
        shape: 'rectangular',
        width: 360,
      });
    };

    const existingScript = document.getElementById('google-identity-services');
    if (existingScript) {
      if (window.google) {
        renderButton();
      } else {
        existingScript.addEventListener('load', renderButton, { once: true });
      }
    } else {
      const script = document.createElement('script');
      script.id = 'google-identity-services';
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.defer = true;
      script.onload = renderButton;
      document.head.appendChild(script);
    }

    return () => {
      disposed = true;
    };
  }, [clientId]);

  if (!clientId) {
    return (
      <p className="auth-google-unavailable">
        Google sign-in is available once <code>VITE_GOOGLE_CLIENT_ID</code> is configured.
      </p>
    );
  }

  return (
    <div className={disabled ? 'auth-google auth-google-disabled' : 'auth-google'}>
      <div ref={containerRef} aria-label="Continue with Google" />
    </div>
  );
}

export function AuthPanel(props: { onAuthenticated: (session: AuthSession) => void }) {
  const [view, setView] = useState<AuthView>('login');
  const [email, setEmail] = useState('');
  const [pendingEmail, setPendingEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [name, setName] = useState('');
  const [otp, setOtp] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [countdown, setCountdown] = useState(0);

  const normalizedEmail = email.trim().toLowerCase();
  const passwordRequirements = useMemo(() => passwordChecks(password), [password]);
  const passedPasswordChecks = passwordRequirements.filter((requirement) => requirement.passed).length;
  const activeEmail = view === 'verify-email' || view === 'reset-password' ? pendingEmail : normalizedEmail;

  useEffect(() => {
    if (countdown <= 0) {
      return;
    }

    const interval = window.setInterval(() => {
      setCountdown((current) => Math.max(0, current - 1));
    }, 1_000);

    return () => window.clearInterval(interval);
  }, [countdown]);

  const showRequestError = useCallback((requestError: unknown, emailForVerification: string) => {
    const apiError = requestError instanceof ApiError ? requestError : null;
    if (apiError?.retryAfterSeconds) {
      setCountdown(apiError.retryAfterSeconds);
    }

    if (apiError?.code === 'EMAIL_NOT_VERIFIED') {
      setPendingEmail(emailForVerification.trim().toLowerCase());
      setView('verify-email');
      setMessage('Verify your email address to continue.');
      setError('');
      return;
    }

    setError(requestError instanceof Error ? requestError.message : 'Something went wrong. Please try again.');
  }, []);

  const completeAuthentication = useCallback((response: AuthResponse, shouldRemember: boolean) => {
    const session: AuthSession = {
      user: response.user,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.expiresAt,
      rememberMe: shouldRemember,
    };
    persistSession(session);
    props.onAuthenticated(session);
  }, [props]);

  const validateCurrentView = (): string | null => {
    if ((view === 'login' || view === 'signup' || view === 'forgot-password') && !emailPattern.test(normalizedEmail)) {
      return 'Enter a valid email address.';
    }

    if (view === 'signup') {
      if (!name.trim()) {
        return 'Enter your full name.';
      }
      if (passedPasswordChecks !== passwordRequirements.length) {
        return 'Choose a stronger password before continuing.';
      }
      if (password !== confirmPassword) {
        return 'Passwords do not match.';
      }
    }

    if (view === 'login' && !password) {
      return 'Enter your password.';
    }

    if ((view === 'verify-email' || view === 'reset-password') && !/^\d{6}$/.test(otp)) {
      return 'Enter the 6-digit code from your email.';
    }

    if (view === 'reset-password') {
      if (passedPasswordChecks !== passwordRequirements.length) {
        return 'Choose a stronger password before continuing.';
      }
      if (password !== confirmPassword) {
        return 'Passwords do not match.';
      }
    }

    return null;
  };

  const submit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const validationError = validateCurrentView();
    if (validationError) {
      setMessage('');
      setError(validationError);
      return;
    }

    setLoading(true);
    setError('');
    setMessage('');

    try {
      if (view === 'login') {
        const response = await postJson<AuthResponse>('/auth/login', {
          email: normalizedEmail,
          password,
          rememberMe,
        });
        completeAuthentication(response, rememberMe);
        return;
      }

      if (view === 'signup') {
        const response = await postJson<{
          message: string;
          verificationEmailSent: boolean;
          retryAfterSeconds?: number;
        }>('/auth/signup', {
          name: name.trim(),
          email: normalizedEmail,
          password,
        });
        setPendingEmail(normalizedEmail);
        setView('verify-email');
        setPassword('');
        setConfirmPassword('');
        setOtp('');
        setCountdown(response.retryAfterSeconds || 0);
        setMessage(response.message);
        return;
      }

      if (view === 'verify-email') {
        const response = await postJson<{ message: string }>('/auth/verify-email', {
          email: pendingEmail,
          otp,
        });
        setView('login');
        setPassword('');
        setOtp('');
        setMessage(response.message);
        return;
      }

      if (view === 'forgot-password') {
        const response = await postJson<OtpResponse>('/auth/forgot-password', { email: normalizedEmail });
        setPendingEmail(normalizedEmail);
        setView('reset-password');
        setPassword('');
        setConfirmPassword('');
        setOtp('');
        setCountdown(response.retryAfterSeconds || 0);
        setMessage(response.message);
        return;
      }

      const response = await postJson<{ message: string }>('/auth/reset-password', {
        email: pendingEmail,
        otp,
        password,
      });
      setView('login');
      setPassword('');
      setConfirmPassword('');
      setOtp('');
      setMessage(response.message);
    } catch (requestError) {
      showRequestError(requestError, normalizedEmail);
    } finally {
      setLoading(false);
    }
  };

  const resendOtp = async () => {
    if (loading || countdown > 0) {
      return;
    }

    setLoading(true);
    setError('');
    setMessage('');
    try {
      const endpoint = view === 'verify-email' ? '/auth/resend-verification' : '/auth/forgot-password';
      const response = await postJson<OtpResponse>(endpoint, { email: activeEmail });
      setCountdown(response.retryAfterSeconds || 60);
      setMessage(response.message);
    } catch (requestError) {
      showRequestError(requestError, activeEmail);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleCredential = useCallback(async (credential: string) => {
    if (loading) {
      return;
    }

    setLoading(true);
    setError('');
    setMessage('');
    try {
      const response = await postJson<AuthResponse>('/auth/google', { idToken: credential });
      completeAuthentication(response, true);
    } catch (requestError) {
      showRequestError(requestError, normalizedEmail);
    } finally {
      setLoading(false);
    }
  }, [completeAuthentication, loading, normalizedEmail, showRequestError]);

  const isPasswordScreen = view === 'signup' || view === 'reset-password';
  const title = view === 'login'
    ? 'Welcome back'
    : view === 'signup'
      ? 'Create your account'
      : view === 'verify-email'
        ? 'Verify your email'
        : view === 'forgot-password'
          ? 'Reset your password'
          : 'Choose a new password';
  const subtitle = view === 'login'
    ? 'Sign in to manage your workforce with confidence.'
    : view === 'signup'
      ? 'Start with secure access to your PayMuster workspace.'
      : view === 'verify-email'
        ? 'Enter the code sent to ' + pendingEmail + '.'
        : view === 'forgot-password'
          ? 'We will send a secure code to your email address.'
          : 'Enter the code we sent to ' + pendingEmail + '.';
  const submitLabel = loading
    ? 'Please wait…'
    : view === 'login'
      ? 'Sign in'
      : view === 'signup'
        ? 'Create account'
        : view === 'verify-email'
          ? 'Verify email'
          : view === 'forgot-password'
            ? 'Send reset code'
            : 'Reset password';

  return (
    <main className="auth-page">
      <section className="auth-card" aria-labelledby="auth-title">
        <div className="auth-brand">
          <img src="/paymuster_logo.png" alt="PayMuster logo" />
          <span>PayMuster</span>
        </div>

        {(view === 'login' || view === 'signup') && (
          <div className="auth-tabs" role="tablist" aria-label="Authentication options">
            <button
              type="button"
              role="tab"
              aria-selected={view === 'login'}
              className={view === 'login' ? 'auth-tab auth-tab-active' : 'auth-tab'}
              onClick={() => {
                setView('login');
                setError('');
                setMessage('');
              }}
            >
              Sign in
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={view === 'signup'}
              className={view === 'signup' ? 'auth-tab auth-tab-active' : 'auth-tab'}
              onClick={() => {
                setView('signup');
                setError('');
                setMessage('');
              }}
            >
              Create account
            </button>
          </div>
        )}

        <header className="auth-heading">
          <h1 id="auth-title">{title}</h1>
          <p>{subtitle}</p>
        </header>

        <div className="auth-status" aria-live="polite">
          {message && <p className="auth-success">{message}</p>}
          {error && <p className="auth-error">{error}</p>}
        </div>

        <form className="auth-form" onSubmit={submit} noValidate>
          {view === 'signup' && (
            <label className="auth-field">
              <span>Full name</span>
              <input
                autoComplete="name"
                value={name}
                onChange={(event) => setName(event.target.value)}
                placeholder="Your name"
                disabled={loading}
              />
            </label>
          )}

          {(view === 'login' || view === 'signup' || view === 'forgot-password') && (
            <label className="auth-field">
              <span>Email address</span>
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="you@company.com"
                disabled={loading}
              />
            </label>
          )}

          {(view === 'verify-email' || view === 'reset-password') && (
            <label className="auth-field">
              <span>6-digit verification code</span>
              <input
                className="auth-otp-input"
                inputMode="numeric"
                autoComplete="one-time-code"
                value={otp}
                onChange={(event) => setOtp(event.target.value.replace(/\D/g, '').slice(0, 6))}
                placeholder="000000"
                maxLength={6}
                disabled={loading}
              />
            </label>
          )}

          {(view === 'login' || isPasswordScreen) && (
            <label className="auth-field">
              <span>Password</span>
              <span className="auth-password-input">
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete={view === 'login' ? 'current-password' : 'new-password'}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder={view === 'login' ? 'Enter your password' : 'Create a strong password'}
                  disabled={loading}
                />
                <button
                  type="button"
                  className="auth-visibility-toggle"
                  onClick={() => setShowPassword((current) => !current)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? 'Hide' : 'Show'}
                </button>
              </span>
            </label>
          )}

          {isPasswordScreen && (
            <>
              <label className="auth-field">
                <span>Confirm password</span>
                <span className="auth-password-input">
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    autoComplete="new-password"
                    value={confirmPassword}
                    onChange={(event) => setConfirmPassword(event.target.value)}
                    placeholder="Repeat your password"
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className="auth-visibility-toggle"
                    onClick={() => setShowConfirmPassword((current) => !current)}
                    aria-label={showConfirmPassword ? 'Hide confirmation password' : 'Show confirmation password'}
                  >
                    {showConfirmPassword ? 'Hide' : 'Show'}
                  </button>
                </span>
              </label>

              <div className="auth-password-strength" aria-label="Password strength requirements">
                <div className="auth-strength-header">
                  <span>Password strength</span>
                  <span>{passedPasswordChecks} of {passwordRequirements.length}</span>
                </div>
                <div className="auth-strength-bar">
                  <span style={{ width: String((passedPasswordChecks / passwordRequirements.length) * 100) + '%' }} />
                </div>
                <ul>
                  {passwordRequirements.map((requirement) => (
                    <li key={requirement.label} className={requirement.passed ? 'auth-check-passed' : ''}>
                      {requirement.passed ? '✓' : '○'} {requirement.label}
                    </li>
                  ))}
                </ul>
              </div>
            </>
          )}

          {view === 'login' && (
            <div className="auth-login-options">
              <label className="auth-checkbox">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(event) => setRememberMe(event.target.checked)}
                  disabled={loading}
                />
                <span>Remember me</span>
              </label>
              <button
                className="auth-link-button"
                type="button"
                onClick={() => {
                  setView('forgot-password');
                  setError('');
                  setMessage('');
                }}
              >
                Forgot password?
              </button>
            </div>
          )}

          <button className="auth-primary-button" type="submit" disabled={loading}>
            {loading && <span className="auth-spinner" aria-hidden="true" />}
            {submitLabel}
          </button>
        </form>

        {(view === 'verify-email' || view === 'reset-password') && (
          <div className="auth-resend">
            <p>Did not receive a code?</p>
            <button
              type="button"
              className="auth-link-button"
              onClick={resendOtp}
              disabled={loading || countdown > 0}
            >
              {countdown > 0 ? 'Resend available in ' + countdownLabel(countdown) : 'Resend code'}
            </button>
          </div>
        )}

        {(view === 'login' || view === 'signup') && (
          <>
            <div className="auth-divider"><span>or</span></div>
            <GoogleSignInButton disabled={loading} onCredential={handleGoogleCredential} />
          </>
        )}

        {(view === 'verify-email' || view === 'forgot-password' || view === 'reset-password') && (
          <button
            type="button"
            className="auth-back-button"
            onClick={() => {
              setView('login');
              setError('');
              setMessage('');
              setOtp('');
              setPassword('');
              setConfirmPassword('');
            }}
          >
            ← Back to sign in
          </button>
        )}

        <p className="auth-security-note">
          Your account is protected with secure one-time codes and encrypted passwords.
        </p>
      </section>
    </main>
  );
}
