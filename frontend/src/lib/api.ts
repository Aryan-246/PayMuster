import { observability } from './observability';

const fallbackBaseUrl = 'http://localhost:4000';

export class ApiError extends Error {
  readonly code?: string;
  readonly retryAfterSeconds?: number;
  readonly status: number;

  constructor(message: string, status: number, code?: string, retryAfterSeconds?: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export function getApiBaseUrl() {
  const configured = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_BACKEND_URL || '';
  return (configured || fallbackBaseUrl).replace(/\/$/, '');
}

export function buildApiUrl(path: string) {
  return getApiBaseUrl() + (path.startsWith('/') ? path : '/' + path);
}

/**
 * Handler invoked when an authenticated request receives a 401. It must return
 * a fresh access token, or null when the session cannot be recovered (the
 * caller then surfaces the original error). Registered by the session layer to
 * avoid an api <-> auth-session import cycle.
 */
export type UnauthorizedHandler = () => Promise<string | null>;

let unauthorizedHandler: UnauthorizedHandler | null = null;

export function setUnauthorizedHandler(handler: UnauthorizedHandler | null) {
  unauthorizedHandler = handler;
}

function isAuthPath(path: string) {
  return path === '/auth/login' || path === '/auth/refresh' || path === '/auth/logout' || path.startsWith('/auth/');
}

async function fetchJson(path: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(buildApiUrl(path), {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...init.headers,
      },
    });
  } catch (error) {
    observability.captureException(error, { operation: 'requestJson', path });
    throw new ApiError('Unable to reach PayMuster. Check your connection and try again.', 0, 'NETWORK_ERROR');
  }
}

export async function requestJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response = await fetchJson(path, init);

  // Session-expiry recovery: a 401 on an authenticated request triggers one
  // refresh + retry via the registered handler. A second 401 (or an auth-path
  // failure) falls through to the normal error surface — no infinite loops.
  if (response.status === 401 && unauthorizedHandler && !isAuthPath(path)) {
    const freshToken = await unauthorizedHandler();
    if (freshToken) {
      const headers = { ...(init.headers as Record<string, string> | undefined) };
      if (headers.Authorization !== undefined) {
        headers.Authorization = `Bearer ${freshToken}`;
      }
      response = await fetchJson(path, { ...init, headers });
    }
  }

  const raw = await response.text();
  let payload: unknown = null;
  if (raw) {
    try {
      payload = JSON.parse(raw);
    } catch (error) {
      observability.captureException(error, { operation: 'requestJson.parse', path, status: response.status });
      throw new ApiError('PayMuster returned an unexpected response. Please try again.', response.status, 'INVALID_RESPONSE');
    }
  }

  if (!response.ok) {
    const error = payload as {
      error?: { message?: string; code?: string; retryAfterSeconds?: number };
    };
    const apiError = new ApiError(
      error.error?.message || 'Something went wrong. Please try again.',
      response.status,
      error.error?.code,
      error.error?.retryAfterSeconds,
    );
    observability.captureException(apiError, {
      operation: 'requestJson.response',
      path,
      status: response.status,
      code: apiError.code,
      requestId: response.headers.get('X-Request-ID') || undefined,
    });
    throw apiError;
  }

  return payload as T;
}

export function postJson<T>(path: string, payload: unknown): Promise<T> {
  return requestJson<T>(path, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function authenticatedPostJson<T>(
  path: string,
  accessToken: string,
  payload: unknown,
  headers?: Record<string, string>,
): Promise<T> {
  return requestJson<T>(path, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...headers,
    },
    body: JSON.stringify(payload),
  });
}

export function authenticatedGetJson<T>(
  path: string,
  accessToken: string,
  headers?: Record<string, string>,
): Promise<T> {
  return requestJson<T>(path, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...headers,
    },
  });
}
