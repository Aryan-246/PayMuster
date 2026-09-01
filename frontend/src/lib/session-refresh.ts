import { setUnauthorizedHandler } from './api';
import { restoreStoredSession } from './auth-session';

/**
 * Mid-session 401 recovery. Concurrent 401s (e.g. parallel react-query
 * refetches) share a single refresh round-trip; when the refresh fails the
 * stored session is already cleared and the registered expiry callback signs
 * the UI out so the user lands on the login panel instead of broken pages.
 */

type SessionExpiredCallback = () => void;

let onSessionExpired: SessionExpiredCallback | null = null;
let inFlightRefresh: Promise<string | null> | null = null;

async function handleUnauthorized(): Promise<string | null> {
  inFlightRefresh ??= restoreStoredSession()
    .then((session) => (session ? session.accessToken : null))
    .finally(() => {
      inFlightRefresh = null;
    });

  const token = await inFlightRefresh;
  if (!token) {
    onSessionExpired?.();
  }
  return token;
}

export function installSessionRefresh(onExpired: SessionExpiredCallback): void {
  onSessionExpired = onExpired;
  setUnauthorizedHandler(handleUnauthorized);
}
