import { isTauri } from '@tauri-apps/api/core';
import { fetch as tauriFetch } from '@tauri-apps/plugin-http';

/** Wyjątek z komunikatem dla użytkowniczki (backend zwraca błędy po polsku). */
export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

const TOKEN_KEY = 'token';
const BASE_URL_KEY = 'baseUrl';
const NAME_KEY = 'displayName';

type Query = Record<string, string>;

// W powłoce Tauri żądania idą przez plugin HTTP (Rust/reqwest) - bez CORS-a
// i bez webview'owej blokady cleartext http://. W czystej przeglądarce
// (npm run dev bez Tauri) zostaje window.fetch.
const httpFetch: typeof globalThis.fetch = isTauri()
  ? (tauriFetch as unknown as typeof globalThis.fetch)
  : globalThis.fetch.bind(globalThis);

class ApiClient {
  /** 10.0.2.2 to localhost komputera widziany z emulatora Androida. */
  baseUrl = $state(localStorage.getItem(BASE_URL_KEY) ?? 'http://10.0.2.2:8080');
  token = $state<string | null>(localStorage.getItem(TOKEN_KEY));
  displayName = $state(localStorage.getItem(NAME_KEY) ?? '');

  get isLoggedIn(): boolean {
    return this.token != null;
  }

  setBaseUrl(url: string): void {
    this.baseUrl = url.trim().replace(/\/+$/, '');
    localStorage.setItem(BASE_URL_KEY, this.baseUrl);
  }

  private saveSession(token: string, name: string): void {
    this.token = token;
    this.displayName = name;
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(NAME_KEY, name);
  }

  logout(): void {
    this.token = null;
    this.displayName = '';
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(NAME_KEY);
  }

  private authHeaders(): Record<string, string> {
    return this.token ? { Authorization: `Bearer ${this.token}` } : {};
  }

  fileUrl(fileId: string): string {
    return `${this.baseUrl}/api/files/${fileId}`;
  }

  private url(path: string, query?: Query): string {
    let u = this.baseUrl + path;
    if (query) {
      u +=
        '?' +
        Object.entries(query)
          .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
          .join('&');
    }
    return u;
  }

  private async decode(res: Response): Promise<any> {
    const text = await res.text();
    if (!res.ok) {
      let message = `Błąd serwera (${res.status})`;
      try {
        const decoded = JSON.parse(text);
        if (typeof decoded?.error === 'string') message = decoded.error;
      } catch {
        // zostaje ogólny komunikat
      }
      throw new ApiError(res.status, message);
    }
    if (!text) return null;
    return JSON.parse(text);
  }

  private async request(method: string, path: string, body?: unknown, query?: Query): Promise<any> {
    let res: Response;
    try {
      res = await httpFetch(this.url(path, query), {
        method,
        headers: { 'Content-Type': 'application/json', ...this.authHeaders() },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      throw new ApiError(0, `Brak połączenia z serwerem (${this.baseUrl})`);
    }
    return this.decode(res);
  }

  get(path: string, query?: Query) {
    return this.request('GET', path, undefined, query);
  }
  post(path: string, body?: unknown) {
    return this.request('POST', path, body);
  }
  put(path: string, body?: unknown) {
    return this.request('PUT', path, body);
  }
  del(path: string) {
    return this.request('DELETE', path);
  }

  /** Pobiera plik (zdjęcie) z nagłówkiem autoryzacji; wynik jako Blob. */
  async fetchBlob(fileId: string): Promise<Blob> {
    let res: Response;
    try {
      res = await httpFetch(this.fileUrl(fileId), { headers: this.authHeaders() });
    } catch {
      throw new ApiError(0, `Brak połączenia z serwerem (${this.baseUrl})`);
    }
    if (!res.ok) throw new ApiError(res.status, `Nie udało się pobrać zdjęcia (${res.status})`);
    return res.blob();
  }

  /**
   * Wysyła zdjęcie (paragon/przepis) i zwraca id pliku. Multipart budowany
   * ręcznie, żeby działał identycznie przez fetch przeglądarki i plugin HTTP.
   */
  async uploadFile(file: File | Blob): Promise<string> {
    const name = (file instanceof File && file.name ? file.name : 'zdjecie.jpg').replace(/"/g, '');
    const boundary = '----OgarniaczkaBoundary' + Math.random().toString(36).slice(2);
    const head =
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="file"; filename="${name}"\r\n` +
      `Content-Type: ${file.type || 'image/jpeg'}\r\n\r\n`;
    const payload = new Blob([head, file, `\r\n--${boundary}--\r\n`]);
    const body = new Uint8Array(await payload.arrayBuffer());
    let res: Response;
    try {
      res = await httpFetch(this.url('/api/files'), {
        method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          ...this.authHeaders(),
        },
        body,
      });
    } catch {
      throw new ApiError(0, `Brak połączenia z serwerem (${this.baseUrl})`);
    }
    const data = await this.decode(res);
    return data.id as string;
  }

  async login(email: string, password: string): Promise<void> {
    const res = await this.post('/api/auth/login', { email, password });
    this.saveSession(res.token, res.user?.displayName ?? '');
  }

  async register(email: string, password: string, displayName: string): Promise<void> {
    const res = await this.post('/api/auth/register', { email, password, displayName });
    this.saveSession(res.token, res.user?.displayName ?? '');
  }
}

export const Api = new ApiClient();
