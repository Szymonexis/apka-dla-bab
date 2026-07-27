import AsyncStorage from '@react-native-async-storage/async-storage';

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

class ApiClient {
  /** 10.0.2.2 to localhost komputera widziany z emulatora Androida. */
  baseUrl = 'http://10.0.2.2:8080';
  token: string | null = null;
  displayName = '';

  async init(): Promise<void> {
    const entries = await AsyncStorage.multiGet([TOKEN_KEY, BASE_URL_KEY, NAME_KEY]);
    const map = Object.fromEntries(entries) as Record<string, string | null>;
    if (map[BASE_URL_KEY]) this.baseUrl = map[BASE_URL_KEY];
    this.token = map[TOKEN_KEY] ?? null;
    this.displayName = map[NAME_KEY] ?? '';
  }

  get isLoggedIn(): boolean {
    return this.token != null;
  }

  async setBaseUrl(url: string): Promise<void> {
    this.baseUrl = url.trim().replace(/\/+$/, '');
    await AsyncStorage.setItem(BASE_URL_KEY, this.baseUrl);
  }

  private async saveSession(token: string, name: string): Promise<void> {
    this.token = token;
    this.displayName = name;
    await AsyncStorage.multiSet([
      [TOKEN_KEY, token],
      [NAME_KEY, name],
    ]);
  }

  async logout(): Promise<void> {
    this.token = null;
    this.displayName = '';
    await AsyncStorage.multiRemove([TOKEN_KEY, NAME_KEY]);
  }

  private authHeaders(): Record<string, string> {
    return this.token ? { Authorization: `Bearer ${this.token}` } : {};
  }

  /** Nagłówki do ładowania obrazków (expo-image wspiera source.headers). */
  get imageHeaders(): Record<string, string> {
    return this.authHeaders();
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
      res = await fetch(this.url(path, query), {
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

  /** Wysyła zdjęcie (paragon/przepis) i zwraca id pliku. */
  async uploadFile(uri: string): Promise<string> {
    const name = uri.split('/').pop() || 'zdjecie.jpg';
    const form = new FormData();
    form.append('file', { uri, name, type: 'image/jpeg' } as unknown as Blob);
    let res: Response;
    try {
      res = await fetch(this.url('/api/files'), {
        method: 'POST',
        headers: this.authHeaders(),
        body: form,
      });
    } catch {
      throw new ApiError(0, `Brak połączenia z serwerem (${this.baseUrl})`);
    }
    const data = await this.decode(res);
    return data.id as string;
  }

  async login(email: string, password: string): Promise<void> {
    const res = await this.post('/api/auth/login', { email, password });
    await this.saveSession(res.token, res.user?.displayName ?? '');
  }

  async register(email: string, password: string, displayName: string): Promise<void> {
    const res = await this.post('/api/auth/register', { email, password, displayName });
    await this.saveSession(res.token, res.user?.displayName ?? '');
  }
}

export const Api = new ApiClient();
