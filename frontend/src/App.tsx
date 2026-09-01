import { useCallback, useEffect, useState } from 'react';
import { AuthPanel } from './components/auth/AuthPanel';
import { PayMusterDashboard } from './components/layout/PayMusterDashboard';
import { postJson } from './lib/api';
import {
  clearStoredSession,
  loadStoredSession,
  restoreStoredSession,
  type AuthSession,
} from './lib/auth-session';
import { installSessionRefresh } from './lib/session-refresh';
import { I18nProvider } from './i18n/I18nProvider';
import { ThemeProvider } from './theme/ThemeProvider';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient();

function App() {
  const [session, setSession] = useState<AuthSession | null>(() => loadStoredSession());
  const [restoringSession, setRestoringSession] = useState(() => loadStoredSession() !== null);
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    // A mid-session 401 (expired access token) triggers one refresh + retry at
    // the request layer; an unrecoverable session signs the UI out here so the
    // user returns to the login panel instead of a stranded error page.
    installSessionRefresh(() => {
      setSession(null);
      setRestoringSession(false);
    });
  }, []);

  useEffect(() => {
    if (!restoringSession) {
      return;
    }

    let active = true;
    void restoreStoredSession().then((restoredSession) => {
      if (active) {
        setSession(restoredSession);
        setRestoringSession(false);
      }
    });

    return () => {
      active = false;
    };
  }, [restoringSession]);

  const handleAuthenticated = useCallback((nextSession: AuthSession) => {
    setSession(nextSession);
  }, []);

  const signOut = useCallback(async () => {
    if (!session || signingOut) {
      return;
    }

    setSigningOut(true);
    try {
      await postJson<{ message: string }>('/auth/logout', { refreshToken: session.refreshToken });
    } catch {
    } finally {
      clearStoredSession();
      setSession(null);
      setSigningOut(false);
    }
  }, [session, signingOut]);

  let content;
  if (restoringSession) {
    content = (
      <main className="auth-page">
        <div className="auth-restore" role="status">
          <span className="auth-spinner" aria-hidden="true" />
          Restoring your secure session…
        </div>
      </main>
    );
  } else if (!session) {
    content = <AuthPanel onAuthenticated={handleAuthenticated} />;
  } else {
    content = (
      <>
        <div className="auth-session-bar">
          <span>Signed in as {session.user.name || session.user.email || 'PayMuster user'}</span>
          <button type="button" onClick={signOut} disabled={signingOut}>
            {signingOut ? 'Signing out…' : 'Sign out'}
          </button>
        </div>
        <PayMusterDashboard session={session} />
      </>
    );
  }

  return (
    <I18nProvider>
      <ThemeProvider>
        <QueryClientProvider client={queryClient}>
          {content}
        </QueryClientProvider>
      </ThemeProvider>
    </I18nProvider>
  );
}

export default App;
