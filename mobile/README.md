# Ogarniaczka - aplikacja mobilna (Expo / React Native)

Aplikacja Android-first napisana w **TypeScript** na **Expo SDK 54** z routingiem
plikowym (**expo-router**). Cała konfiguracja natywna żyje w `app.json` -
katalogi `android/`/`ios/` generuje prebuild, niczego nie edytuje się ręcznie.

## Szybki start (Expo Go - bez Android SDK)

1. Zainstaluj [Node.js LTS](https://nodejs.org) i aplikację **Expo Go** na telefonie
   (Google Play).
2. Odpal backend w katalogu głównym repo: `docker compose up -d --build`.
3. Uruchom serwer deweloperski i zeskanuj QR telefonem:

   ```bash
   cd mobile
   npm install
   npx expo start
   ```

4. **Adres serwera** (ikona ⚙️ w apce, także przed zalogowaniem): telefon z Expo Go
   łączy się przez Wi-Fi, więc ustaw `http://<IP-komputera>:8080` (IP sprawdzisz
   `ip addr` / `ipconfig`). Domyślne `http://10.0.2.2:8080` działa tylko w emulatorze.

> W Expo Go działa wszystko łącznie z lokalnymi alarmami przypomnień; pełną
> kontrolę nad powiadomieniami (ikona, kanały, dokładność co do minuty) daje
> development build - patrz niżej.

## Build natywny (emulator / APK)

```bash
npx expo run:android        # wymaga Android Studio (SDK) + JDK 17
```

albo w chmurze / lokalnie przez EAS:

```bash
npx eas build --platform android --profile preview   # APK do udostępnienia
npx eas build --local ...                            # build lokalny, bez limitów chmury
```

Bonus Expo: **EAS Update** pozwala wysyłać poprawki JS na telefony bez
przeinstalowywania APK (`npx eas update`).

## Powiadomienia

- **Lokalne alarmy** (`expo-notifications`): apka przy każdej synchronizacji
  przypomnień przeplanowuje je w systemie - dzwonią bez internetu i przy
  zamkniętej aplikacji. Uprawnienia `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`
  i `RECEIVE_BOOT_COMPLETED` są już zadeklarowane w `app.json`.
- **Push przez własny serwer ntfy** (opcjonalny): Ustawienia → sekcja
  „Powiadomienia" pokazuje sekretny temat i adres serwera; instalujesz darmową
  aplikację [ntfy](https://ntfy.sh/), subskrybujesz temat i push dochodzi nawet
  przy zabitej apce (obsługa w całości po stronie backendu).

## Konfiguracja natywna (app.json)

- `expo-build-properties` → `usesCleartextTraffic: true` - żeby działał `http://`
  do backendu w domowej sieci (przy wystawianiu backendu w internet przejdź na
  HTTPS i usuń tę flagę),
- `expo-image-picker` (aparat/galeria do zdjęć paragonów i przepisów),
- ikona + adaptive icon (różowe serduszko) w `assets/`.

## Struktura

```
app/                      # expo-router: plik = ekran
├── _layout.tsx           # stack, motyw, inicjalizacja Api
├── login.tsx             # logowanie / rejestracja
├── (tabs)/               # dolna nawigacja
│   ├── index.tsx         #   Dziś: przypomnienia, obowiązki, wydarzenia, posiłki
│   ├── week.tsx          #   Plan tygodnia
│   ├── kitchen.tsx       #   Kuchnia: Przepisy / Jadłospis / Dzienniczek
│   ├── budget.tsx        #   Budżet: podsumowanie, limity, transakcje
│   └── notes.tsx         #   Notatki (siatka 2 kolumny)
├── task-edit.tsx, reminder-edit.tsx, event-edit.tsx,
├── meal-edit.tsx, diary-edit.tsx, note-edit.tsx,
├── recipe/[id].tsx       # szczegóły przepisu (+ plan na jadłospis)
├── recipe-edit.tsx       # edycja przepisu + zdjęcie
├── transaction.tsx       # transakcja + ZDJĘCIE PARAGONU 🧾
├── reminders.tsx, tasks.tsx, settings.tsx, photo.tsx
components/
├── ui.tsx                # Card, SectionHeader, EmptyState, Fab, toasty...
├── forms.tsx             # Input, PickerField, DateField, TimeField, ActionSheet
└── kitchen/              # trzy zakładki Kuchni
lib/
├── api.ts                # klient HTTP + JWT + upload zdjęć (singleton Api)
├── models.ts             # typy 1:1 z backendem
├── util.ts               # grosze, daty (polskie nazwy), słowniki
├── notifications.ts      # lokalne alarmy przypomnień
├── stash.ts              # przekazywanie obiektu do ekranu edycji
└── theme.ts              # kolory
```

## Przydatne komendy

```bash
npm run typecheck          # tsc --noEmit (strict)
npx expo start -c          # dev server z czystym cache Metro
npx expo export --platform android   # test pełnego bundla (Metro + Hermes)
npx expo install --fix     # wyrównanie wersji pakietów do SDK (wymaga internetu)
```
