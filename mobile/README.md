# Ogarniaczka - aplikacja mobilna (Flutter)

Aplikacja Android-first (Flutter, Material 3, po polsku). W repo trzymamy tylko
`lib/` + `pubspec.yaml` - katalog `android/` generujesz jedną komendą u siebie.

## Pierwsze uruchomienie

1. Zainstaluj [Flutter SDK](https://docs.flutter.dev/get-started/install) i Android Studio (SDK + emulator).
2. Wygeneruj pliki platformy Android (istniejące pliki NIE zostaną nadpisane):

   ```bash
   cd mobile
   flutter create --project-name ogarniaczka --org pl.apka --platforms android .
   flutter pub get
   ```

3. **Dev po HTTP** (backend na `http://...` bez TLS): w
   `android/app/src/main/AndroidManifest.xml` dodaj do tagu `<application>`:

   ```xml
   android:usesCleartextTraffic="true"
   ```

   (Android od wersji 9 domyślnie blokuje ruch nieszyfrowany. Na produkcji użyj HTTPS
   i usuń ten atrybut.)

4. **Lokalne alarmy przypomnień** (`flutter_local_notifications`) wymagają dwóch
   rzeczy w wygenerowanym katalogu `android/`:

   a) *Core library desugaring* w `android/app/build.gradle`:

   ```gradle
   android {
       compileOptions {
           coreLibraryDesugaringEnabled true
           sourceCompatibility JavaVersion.VERSION_1_8
           targetCompatibility JavaVersion.VERSION_1_8
       }
   }
   dependencies {
       coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
   }
   ```

   b) uprawnienia i odbiorniki w `AndroidManifest.xml` (żeby alarmy przeżywały
   restart telefonu i dzwoniły punktualnie):

   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   <!-- wewnątrz <application>: -->
   <receiver android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
   <receiver android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
       <intent-filter>
           <action android:name="android.intent.action.BOOT_COMPLETED"/>
           <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
           <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
       </intent-filter>
   </receiver>
   ```

5. Odpal backend (`docker compose up -d --build` w katalogu głównym repo) i aplikację:

   ```bash
   flutter run
   ```

6. Adres serwera zmienisz w apce: ikona **⚙️** (także na ekranie logowania).
   - Emulator Androida: `http://10.0.2.2:8080` (ustawiony domyślnie; tak emulator widzi
     localhost Twojego komputera).
   - Prawdziwy telefon: komputer i telefon w tej samej sieci Wi-Fi, adres
     `http://<IP-komputera>:8080` (IP sprawdzisz np. `ip addr` / `ipconfig`).

7. Po wygenerowaniu `android/` zacommituj go - wtedy każdy buduje identycznie.

## Powiadomienia

- **Lokalne alarmy** (bez konfiguracji): przypomnienia dzwonią o właściwej porze
  nawet bez internetu i przy zamkniętej aplikacji - apka planuje je w systemowym
  AlarmManagerze przy każdej synchronizacji listy przypomnień.
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
    └── settings_screen.dart   # adres serwera, test połączenia, wylogowanie
```

## Uprawnienia

- Internet: dodawany automatycznie w buildach debug; do builda release upewnij się,
  że w manifeście jest `<uses-permission android:name="android.permission.INTERNET"/>`.
- Aparat/galeria: `image_picker` używa systemowych intentów - nie wymaga własnych
  wpisów uprawnień na Androidzie.
