// Przekazywanie obiektu do ekranu edycji bez serializowania go w URL:
// lista robi setStash(obiekt) i router.push(...), ekran edycji robi takeStash().

let value: unknown;

export function setStash<T>(v: T): void {
  value = v;
}

export function takeStash<T>(): T | undefined {
  const v = value as T | undefined;
  value = undefined;
  return v;
}
