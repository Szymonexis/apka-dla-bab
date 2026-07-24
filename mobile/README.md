# Ogarniaczka - aplikacja mobilna (Flutter)

Aplikacja Android-first (Flutter, Material 3, po polsku). Katalog `android/`
jest **w całości w repo** - skonfigurowany manifest, gradle z desugaringiem,
ikony i motywy. Niczego nie trzeba generować ani edytować ręcznie.

## Pierwsze uruchomienie

1. Zainstaluj [Flutter SDK](https://docs.flutter.dev/get-started/install)
   i Android Studio (SDK + emulator albo telefon po USB).
2. Odpal backend w katalogu głównym repo: `docker compose up -d --build`.
3. Uruchom aplikację:

   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

   (`local.properties` ze ścieżkami SDK wygeneruje się samo przy pierwszym
   uruchomieniu.)

4. Adres serwera zmienisz w apce: ikona **⚙️** (także na ekranie logowania).
   - Emulator Androida: `http://10.0.2.2:8080` (ustawiony domyślnie; tak emulator
     widzi localhost Twojego komputera).
   - Prawdziwy telefon: komputer i telefon w tej samej sieci Wi-Fi, adres
     `http://<IP-komputera>:8080` (IP sprawdzisz np. `ip addr` / `ipconfig`).

## Co jest już skonfigurowane w `android/`

- **Manifest**: uprawnienia `INTERNET`, `POST_NOTIFICATIONS` (Android 13+),
  `RECEIVE_BOOT_COMPLETED` + `SCHEDULE_EXACT_ALARM` (punktualne alarmy, które
  przeżywają restart telefonu) oraz odbiorniki `flutter_local_notifications`.
- **`android:usesCleartextTraffic="true"`** - żeby działał `http://` do backendu
  w domowej sieci. Przy wystawianiu backendu w internet przejdź na HTTPS i usuń
  ten atrybut z `app/src/main/AndroidManifest.xml`.
- **Gradle**: AGP 8.3.2 + Kotlin 1.9.24 + Gradle 8.7 (wrapper w repo),
  *core library desugaring* wymagany przez `flutter_local_notifications`.
- **Ikona**: różowe serduszko we wszystkich rozdzielczościach
  (`res/mipmap-*/ic_launcher.png`).
- **Release** jest tymczasowo podpisywany kluczem debug, żeby
  `flutter run --release` działało od ręki - przed publikacją w sklepie
  skonfiguruj własny klucz (`key.properties`).

iOS: katalogu `ios/` nie ma w repo - w razie potrzeby `flutter create --platforms ios .`
(ten sam kod Darta zadziała).

## Powiadomienia

- **Lokalne alarmy** (bez konfiguracji): przypomnienia dzwonią o właściwej porze
  nawet bez internetu i przy zamkniętej aplikacji - apka planuje je w systemowym
  AlarmManagerze przy każdej synchronizacji listy przypomnień. Przy pierwszym
  starcie Android zapyta o zgodę na powiadomienia (13+) i dokładne alarmy (12+).
- **Push przez własny serwer ntfy** (opcjonalny): Ustawienia → sekcja
  „Powiadomienia" pokazuje Twój sekretny temat i adres serwera. Zainstaluj
  darmową aplikację [ntfy](https://ntfy.sh/) (Google Play/F-Droid), dodaj
  subskrypcję tego tematu ze swoim serwerem i gotowe - przypomnienia oraz
  poranne podsumowanie obowiązków przychodzą jako push, nawet na inne urządzenia.

## Struktura

```
lib/
├── main.dart                  # motyw, lokalizacja PL, bramka logowania
├── api/api_client.dart        # HTTP + JWT + upload zdjęć (singleton Api.i)
├── models/models.dart         # modele 1:1 z API
├── util.dart                  # kwoty (grosze), daty, słowniki (posiłki, kategorie)
├── notifications_service.dart # lokalne alarmy przypomnień
├── dialogs.dart               # wspólne dialogi dodawania/edycji
├── widgets/common.dart        # SectionHeader, EmptyState, snackbary
└── screens/
    ├── home_shell.dart        # dolna nawigacja: Dziś | Tydzień | Kuchnia | Budżet | Notatki
    ├── today_screen.dart      # dzisiejsze przypomnienia, obowiązki, wydarzenia, posiłki + szybkie dodawanie
    ├── week_screen.dart       # plan tygodnia (wydarzenia + obowiązki + jadłospis)
    ├── kitchen_screen.dart    # zakładki: Przepisy / Jadłospis / Dzienniczek
    ├── budget_screen.dart     # podsumowanie miesiąca, limity, transakcje
    ├── transaction_edit_screen.dart  # kwota, kategoria, ZDJĘCIE PARAGONU 🧾
    ├── notes_screen.dart      # siatka notatek + edycja
    ├── reminders_screen.dart  # przypomnienia
    ├── tasks_screen.dart      # wszystkie obowiązki
    └── settings_screen.dart   # adres serwera, powiadomienia push, wylogowanie
```

## Uprawnienia w skrócie

| Uprawnienie | Po co |
|---|---|
| `INTERNET` | komunikacja z backendem |
| `POST_NOTIFICATIONS` | pokazywanie powiadomień (Android 13+) |
| `SCHEDULE_EXACT_ALARM` | przypomnienia dzwonią punktualnie (Android 12+) |
| `RECEIVE_BOOT_COMPLETED` | alarmy wracają po restarcie telefonu |

Aparat/galeria: `image_picker` używa systemowych intentów - nie wymaga własnych
wpisów uprawnień.
