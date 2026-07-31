# Ogarniaczka - aplikacja mobilna (Tauri 2 + Svelte 5)

Mobilny klient **Ogarniaczki** napisany w **Svelte 5 (runes)** z powłoką
**Tauri 2**: cały interfejs i logika żyją we frontendzie (TypeScript + Vite),
a Rust jest cienką warstwą systemową (webview + pluginy). Ta sama baza kodu
działa jako aplikacja Android oraz aplikacja desktopowa (przydatne do
developmentu).

## Stack

| Warstwa | Technologia |
|---|---|
| UI | Svelte 5.56+ (runes: `$state`, `$derived`, `$effect`, `$props`, snippety) |
| Bundler | Vite 8 + `@sveltejs/vite-plugin-svelte` 7 |
| Powłoka | Tauri 2 (webview systemowy, binarka Rust) |
| HTTP | `@tauri-apps/plugin-http` - żądania idą przez Rusta (reqwest), więc nie dotyczy ich CORS ani webview'owa blokada cleartext `http://` |
| Powiadomienia | `@tauri-apps/plugin-notification` - lokalne alarmy przypomnień planowane w systemie (Android) |
| Stan/sesja | runy w modułach `.svelte.ts` (`Api`, router, toasty, dialogi) + `localStorage` (token JWT, adres serwera) |
| Routing | własny mini-router hashowy (~60 linii) - prawdziwa historia przeglądarki, więc systemowy przycisk "wstecz" na Androidzie działa za darmo |

## Szybki start (desktop - bez Android SDK)

Wymagany [Node.js LTS](https://nodejs.org) oraz [Rust](https://rustup.rs)
(stable). Backend odpal w katalogu głównym repo: `docker compose up -d --build`.

```bash
npm install
npm run tauri dev        # okno desktopowe 420x880 z apką
```

W apce (ikona ⚙️, dostępna też przed zalogowaniem) ustaw adres serwera,
np. `http://localhost:8080`.

> Czysty podgląd webowy bez Rusta: `npm run dev` i przeglądarka pod
> `http://localhost:1420` (żądania idą wtedy zwykłym `fetch` - backend ma
> otwarte CORS, więc też działa).

## Android

Jednorazowo: Android Studio (SDK + NDK), zmienne `ANDROID_HOME` / `NDK_HOME`
oraz cele Rusta:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi \
  i686-linux-android x86_64-linux-android

npm run tauri android init      # generuje projekt w src-tauri/gen/android
npm run tauri android dev       # emulator / podłączony telefon
npm run tauri android build     # APK/AAB
```

Adres serwera w apce:

- emulator Androida: `http://10.0.2.2:8080` (domyślny),
- prawdziwy telefon: `http://<IP-komputera>:8080` w tej samej sieci Wi-Fi.

Uwagi Android:

- **API po `http://`**: żądania do backendu idą przez plugin HTTP (Rust),
  więc *nie* podlegają blokadzie cleartext webview'a. Blokada dotyczy tylko
  treści ładowanych przez sam webview - przy pracy w domowej sieci nie trzeba
  nic zmieniać, a przy wystawianiu backendu w internet i tak przechodzi się
  na HTTPS.
- **Uprawnienia powiadomień** (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`)
  dodaje plugin notification; zgoda jest pytana przy pierwszej synchronizacji
  przypomnień.
- **Zdjęcia paragonów/przepisów**: systemowy wybór pliku/aparatu webview'a
  (`<input type="file" accept="image/*" capture>`); jeśli chcesz zdjęcia z
  aparatu, dodaj `<uses-permission android:name="android.permission.CAMERA"/>`
  w wygenerowanym `src-tauri/gen/android/app/src/main/AndroidManifest.xml`.
- Ikony mipmap dla Androida wygenerujesz z bazowej:
  `npm run tauri icon src-tauri/icons/icon.png`.

## Struktura

```
index.html, vite.config.ts     # wejście Vite (port 1420 pod Tauri)
src/
├── main.ts                    # mount(App)
├── app.css                    # motyw (CSS variables) + wspólne klasy UI
├── App.svelte                 # przełącznik ekranów po trasie + hosty toastów/dialogów
├── lib/
│   ├── api.svelte.ts          # klient HTTP: JWT, upload multipart, stan sesji w runach
│   ├── router.svelte.ts       # mini-router hashowy ($state + hashchange)
│   ├── toast.svelte.ts       # kolejka toastów
│   ├── dialog.svelte.ts       # dialogi na promisach (odpowiednik Alert.alert)
│   ├── notifications.ts       # lokalne alarmy przypomnień (plugin notification)
│   ├── photos.ts              # wybór zdjęcia (galeria/aparat przez <input type=file>)
│   ├── models.ts              # typy 1:1 z backendem
│   ├── util.ts                # grosze, daty (polskie nazwy), słowniki
│   └── stash.ts               # przekazywanie obiektu do ekranu edycji
├── components/                # Card, Fab, Input, PickerField, DateField,
│                              # ActionSheet, AuthImage, Icon (własne SVG)...
└── screens/
    ├── TabsScreen.svelte      # dolna nawigacja
    ├── tabs/                  # Dziś, Tydzień, Kuchnia, Budżet, Notatki
    ├── kitchen/               # Przepisy / Jadłospis / Dzienniczek
    └── *.svelte               # login, ekrany edycji, przepis, transakcja,
                               # przypomnienia, obowiązki, ustawienia, zdjęcie
src-tauri/
├── src/lib.rs                 # Builder + pluginy (http, notification)
├── tauri.conf.json            # okno, devUrl, frontendDist, ikony
└── capabilities/default.json  # uprawnienia: notification + http (scope URL)
```

## Jak to jest poskładane

- **Runes zamiast store'ów**: współdzielony stan (sesja `Api`, trasa routera,
  kolejka toastów, aktywny dialog) to zwykłe pola `$state` w modułach
  `.svelte.ts`; komponenty czytają je przez gettery i wszystko jest reaktywne
  bez subskrypcji.
- **Odświeżanie po powrocie**: każda nawigacja podbija `router.epoch`,
  a `App.svelte` trzyma ekran w `{#key epoch}` - ekran montuje się od nowa
  i pobiera świeże dane (odpowiednik "focus effect"). Stan zakładek
  (aktywna zakładka, przesunięcie tygodnia, wybrany miesiąc) żyje w
  `<script module>`, więc powroty go nie zerują.
- **Obrazki zza autoryzacji**: `<img>` nie wyśle nagłówka `Bearer`, więc
  `AuthImage` pobiera plik fetchem z tokenem i pokazuje blob-URL.
- **Upload**: multipart budowany ręcznie (boundary + `Uint8Array`), przez co
  identycznie działa w fetchu przeglądarki i w pluginie HTTP.
- **Pickery daty/godziny**: natywne `input[type=date/time]` webview'a
  (na Androidzie systemowe dialogi Materiala) opakowane w ładne pole;
  na silnikach bez `showPicker()` pole degraduje się do widocznego inputa.

## Przydatne komendy

```bash
npm run check            # svelte-check (tsc dla .svelte + .ts, strict)
npm run build            # produkcyjny bundle frontendu do dist/
npm run tauri dev        # desktopowa apka deweloperska (hot reload)
npm run tauri android dev
cargo check              # (w src-tauri/) sama kompilacja powłoki Rust
```
