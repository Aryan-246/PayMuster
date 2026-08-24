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

export async function requestJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(buildApiUrl(path), {
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

export function authenticatedPostJson<T>(path: string, accessToken: string, payload: unknown): Promise<T> {
  return requestJson<T>(path, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  });
}
