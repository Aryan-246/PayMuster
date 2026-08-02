import { postJson } from './api';

export interface AuthenticatedUser {
  id: string;
  email: string | null;
  name: string | null;
  provider: string | null;
  emailVerified: boolean;
  role: string;
  orgId: string;
}

export interface AuthSession {
  user: AuthenticatedUser;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  rememberMe: boolean;
}

const storageKey = 'paymuster.auth.session';

function hasBrowserStorage(): boolean {
  return typeof window !== 'undefined';
}

function parseSession(value: string | null): AuthSession | null {
  if (!value) {
    return null;
  }

  try {
    const parsed = JSON.parse(value) as Partial<AuthSession>;
    if (
      !parsed.user
      || typeof parsed.accessToken !== 'string'
      || typeof parsed.refreshToken !== 'string'
      || typeof parsed.expiresAt !== 'string'
      || typeof parsed.rememberMe !== 'boolean'
    ) {
      return null;
    }
    return parsed as AuthSession;
  } catch {
    return null;
  }
}

export function loadStoredSession(): AuthSession | null {
  if (!hasBrowserStorage()) {
    return null;
  }

  return parseSession(window.localStorage.getItem(storageKey))
    || parseSession(window.sessionStorage.getItem(storageKey));
}

export function persistSession(session: AuthSession): void {
  if (!hasBrowserStorage()) {
    return;
  }

  clearStoredSession();
  const storage = session.rememberMe ? window.localStorage : window.sessionStorage;
  storage.setItem(storageKey, JSON.stringify(session));
}

export function clearStoredSession(): void {
  if (!hasBrowserStorage()) {
    return;
  }

  window.localStorage.removeItem(storageKey);
  window.sessionStorage.removeItem(storageKey);
}

export async function restoreStoredSession(): Promise<AuthSession | null> {
  const session = loadStoredSession();
  if (!session) {
    return null;
  }

  try {
    const refreshed = await postJson<{ accessToken: string; expiresAt: string }>('/auth/refresh', {
      refreshToken: session.refreshToken,
    });
    const nextSession: AuthSession = {
      ...session,
      accessToken: refreshed.accessToken,
      expiresAt: refreshed.expiresAt,
    };
    persistSession(nextSession);
    return nextSession;
  } catch {
    clearStoredSession();
    return null;
  }
}
