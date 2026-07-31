// Minimalny router hashowy na runach. Prawdziwa historia przeglądarki
// (location.hash + history.back) daje za darmo obsługę systemowego
// przycisku "wstecz" na Androidzie. `epoch` rośnie przy każdej nawigacji -
// App.svelte używa go w {#key}, żeby ekrany montowały się od nowa
// (odpowiednik odświeżania danych przy powrocie na ekran).

export interface Route {
  name: string;
  params: Record<string, string>;
}

function parse(): Route {
  const raw = location.hash.replace(/^#\/?/, '');
  const [path = '', qs = ''] = raw.split('?');
  return { name: path || 'tabs', params: Object.fromEntries(new URLSearchParams(qs)) };
}

function serialize(name: string, params?: Record<string, string>): string {
  const qs = params && Object.keys(params).length > 0 ? '?' + new URLSearchParams(params).toString() : '';
  return `#/${name}${qs}`;
}

let current = $state.raw<Route>(parse());
let epoch = $state(0);

window.addEventListener('hashchange', () => {
  current = parse();
  epoch += 1;
});

export const router = {
  get route(): Route {
    return current;
  },
  get epoch(): number {
    return epoch;
  },
  push(name: string, params?: Record<string, string>): void {
    location.hash = serialize(name, params);
  },
  replace(name: string, params?: Record<string, string>): void {
    history.replaceState(null, '', serialize(name, params));
    current = parse();
    epoch += 1;
  },
  back(): void {
    if (history.length > 1) history.back();
    else router.replace('tabs');
  },
};
