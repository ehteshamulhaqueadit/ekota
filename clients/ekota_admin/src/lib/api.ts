const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000/api';

export const apiBaseUrl = baseUrl.replace(/\/$/, '');

function readSessionToken() {
  const sessionRaw = localStorage.getItem('ekota_admin_session');

  if (!sessionRaw) {
    return null;
  }

  try {
    const session = JSON.parse(sessionRaw) as { token?: unknown };

    return typeof session.token === 'string' ? session.token : null;
  } catch {
    return null;
  }
}

export async function apiRequest(path: string, options: RequestInit = {}) {
  const token = readSessionToken();

  const response = await fetch(`${apiBaseUrl}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
    ...options,
  });

  const text = await response.text();
  let payload: unknown = null;

  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }

  if (!response.ok) {
    const message =
      typeof payload === 'object' && payload && 'message' in payload
        ? String((payload as { message?: unknown }).message)
        : typeof payload === 'object' && payload && 'error' in payload
          ? String((payload as { error?: unknown }).error)
          : 'Request failed';
    throw new Error(message);
  }

  return payload;
}
