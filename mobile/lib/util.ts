// Pomocnicze: pieniądze (grosze), daty (bez bibliotek, polskie nazwy na sztywno),
// słowniki posiłków/kategorii - port 1:1 z wersji Flutterowej.

export function formatMoney(grosze: number): string {
  const sign = grosze < 0 ? '-' : '';
  const abs = Math.abs(grosze);
  const zl = Math.floor(abs / 100);
  const gr = abs % 100;
  const zlStr = zl.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${sign}${zlStr},${gr.toString().padStart(2, '0')} zł`;
}

export function parseMoney(input: string): number | null {
  const cleaned = input.trim().replace(/[\s ]/g, '').replace('zł', '').replace(',', '.');
  if (!cleaned) return null;
  const value = Number(cleaned);
  if (!Number.isFinite(value) || value < 0) return null;
  return Math.round(value * 100);
}

const DAY_SHORT = ['nd', 'pon', 'wt', 'śr', 'czw', 'pt', 'sob'];
const DAY_FULL = ['niedziela', 'poniedziałek', 'wtorek', 'środa', 'czwartek', 'piątek', 'sobota'];
const MONTH_GEN = ['stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
  'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'];
const MONTH_NOM = ['styczeń', 'luty', 'marzec', 'kwiecień', 'maj', 'czerwiec',
  'lipiec', 'sierpień', 'wrzesień', 'październik', 'listopad', 'grudzień'];

const pad = (n: number) => n.toString().padStart(2, '0');

export function dateStr(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function monthStr(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
}

export function dayOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function addDays(d: Date, days: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + days);
  return x;
}

export function mondayOf(d: Date): Date {
  const x = dayOnly(d);
  return addDays(x, -((x.getDay() + 6) % 7));
}

export function todayStr(): string {
  return dateStr(new Date());
}

/** 'YYYY-MM-DD' -> Date (lokalna północ) */
export function parseLocalDate(s: string): Date {
  const [y, m, d] = s.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/** 'YYYY-MM-DD' -> 'pt, 24 lipca' */
export function prettyDate(yyyyMmDd: string): string {
  const d = parseLocalDate(yyyyMmDd);
  return `${DAY_SHORT[d.getDay()]}, ${d.getDate()} ${MONTH_GEN[d.getMonth()]}`;
}

/** Date/ISO -> 'pt, 24 lipca 14:30' (czas lokalny) */
export function prettyDateTime(iso: string | Date): string {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  return `${DAY_SHORT[d.getDay()]}, ${d.getDate()} ${MONTH_GEN[d.getMonth()]} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** 'poniedziałek, 24.07' */
export function dayHeader(d: Date): string {
  return `${DAY_FULL[d.getDay()]}, ${d.getDate()}.${pad(d.getMonth() + 1)}`;
}

/** 'niedziela, 24 lipca' */
export function longDate(d: Date): string {
  return `${DAY_FULL[d.getDay()]}, ${d.getDate()} ${MONTH_GEN[d.getMonth()]}`;
}

/** 'lipiec 2026' */
export function monthHeader(d: Date): string {
  return `${MONTH_NOM[d.getMonth()]} ${d.getFullYear()}`;
}

/** '24 lip' */
export function shortDate(d: Date): string {
  return `${d.getDate()} ${MONTH_GEN[d.getMonth()].slice(0, 3)}`;
}

export function timeOf(iso: string): string {
  const d = new Date(iso);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export const mealTypes = ['sniadanie', 'drugie_sniadanie', 'obiad', 'podwieczorek', 'kolacja', 'przekaska'] as const;
export type MealType = (typeof mealTypes)[number];

export const mealTypeLabels: Record<string, string> = {
  sniadanie: 'Śniadanie',
  drugie_sniadanie: 'II śniadanie',
  obiad: 'Obiad',
  podwieczorek: 'Podwieczorek',
  kolacja: 'Kolacja',
  przekaska: 'Przekąska',
};

export const mealTypeEmoji: Record<string, string> = {
  sniadanie: '🍳',
  drugie_sniadanie: '🥪',
  obiad: '🍲',
  podwieczorek: '🍰',
  kolacja: '🥗',
  przekaska: '🍎',
};

export const txCategories = ['jedzenie', 'dom', 'rachunki', 'transport', 'zdrowie', 'uroda',
  'ubrania', 'dzieci', 'zwierzaki', 'rozrywka', 'prezenty', 'inne'];

export const categoryEmoji: Record<string, string> = {
  jedzenie: '🛒',
  dom: '🏠',
  rachunki: '🧾',
  transport: '🚗',
  zdrowie: '💊',
  uroda: '💅',
  ubrania: '👗',
  dzieci: '🧸',
  zwierzaki: '🐾',
  rozrywka: '🎉',
  prezenty: '🎁',
  inne: '✨',
};

export const repeatLabels: Record<string, string> = {
  none: 'Nie powtarza się',
  daily: 'Codziennie',
  weekly: 'Co tydzień',
  monthly: 'Co miesiąc',
};

export function mealOrder(mealType: string): number {
  const idx = (mealTypes as readonly string[]).indexOf(mealType);
  return idx < 0 ? 99 : idx;
}
