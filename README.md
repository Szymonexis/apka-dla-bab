# Ogarniaczka 🏡💗

**Jedna apka zamiast pięćdziesięciu** - domowy organizer do prowadzenia siebie i domu:
notatki, przypomnienia, kalendarz i plan tygodnia, obowiązki do odhaczania, przepisy
i pomysły na obiad, dzienniczek żywieniowy oraz budżet domowy ze zdjęciami paragonów.

## Funkcjonalności (MVP)

| Moduł | Co robi |
|---|---|
| 📝 **Notatki** | szybkie notatki z przypinaniem ważnych na górę |
| 🔔 **Przypomnienia** | "umów przegląd", "kup prezent" - z datą i godziną, do odhaczenia |
| 📅 **Kalendarz + plan tygodnia** | wydarzenia z godziną lub całodniowe; widok tygodnia łączy wydarzenia, obowiązki i jadłospis |
| ✅ **Obowiązki** | do odhaczenia; powtarzalne (codziennie / co tydzień / co miesiąc) same planują kolejny termin po odhaczeniu |
| 👩‍🍳 **Przepisy** | składniki, kroki, tagi, czas, zdjęcie, ulubione + **losowanie pomysłu na obiad** 🎲 |
| 🍽️ **Jadłospis** | planowanie posiłków na konkretne dni (przepis z bazy albo dowolny wpis) |
| 🥗 **Dzienniczek żywieniowy** | co zjadłam + kalorie, suma dzienna |
| 💰 **Budżet domowy** | wydatki/przychody, kategorie, limity miesięczne z paskami postępu, **zdjęcia paragonów** (aparat/galeria) |
| 🔔 **Powiadomienia** | lokalne alarmy przypomnień (bez żadnej infrastruktury) + opcjonalny push przez **własny serwer ntfy** (self-hosted, bez zewnętrznych płatnych usług): przypomnienia i poranne podsumowanie obowiązków |
| 👤 **Konta** | rejestracja/logowanie (JWT), każdy użytkownik widzi tylko swoje dane |

## Architektura

```mermaid
flowchart LR
    subgraph Telefon
        A["📱 Aplikacja mobilna<br/>Flutter (Android-first)<br/>+ lokalne alarmy przypomnień"]
        F["🔔 Aplikacja ntfy<br/>(opcjonalnie, open source)"]
    end
    subgraph "Docker Compose"
        B["🚀 Backend API<br/>Go + chi (REST, JWT)<br/>+ dyspozytor powiadomień"]
        C[("🗄️ PostgreSQL 16<br/>dane aplikacji")]
        D[("🪣 MinIO<br/>zdjęcia paragonów i przepisów")]
        E["📮 ntfy<br/>self-hosted push"]
    end
    A -- "HTTP/JSON + Bearer token" --> B
    B -- "pgx (SQL)" --> C
    B -- "S3 API" --> D
    B -- "publikacja powiadomień" --> E
    E -- "push (sekretny temat)" --> F
```

Decyzje projektowe:

- **REST + JSON** - prosto, przewidywalnie, łatwo dodać kolejne klienty (web).
- **JWT (30 dni)** - bezstanowy backend, token trzymany w aplikacji.
- **Kwoty w groszach (`BIGINT`)** - zero problemów z zaokrągleniami float.
- **Pliki przez backend** (`POST /api/files` → MinIO, `GET /api/files/{id}` streamuje z powrotem) -
  telefon nie musi znać adresu MinIO, a dostęp do zdjęć jest autoryzowany per użytkownik.
- **Migracje SQL wbudowane w binarkę** - backend sam migruje bazę przy starcie, bez dodatkowych narzędzi.
- **Wszystkie tabele mają `user_id`** - izolacja danych na poziomie każdego zapytania.
- **Powiadomienia bez płatnych usług** - dwa niezależne poziomy (szczegóły niżej):
  lokalne alarmy w telefonie + self-hostowany [ntfy](https://ntfy.sh) w Dockerze.

## Struktura repozytorium

```
├── docker-compose.yml        # postgres + minio + ntfy + backend
├── .env.example              # konfiguracja (skopiuj do .env)
├── backend/                  # Go 1.24
│   ├── cmd/server/           # main: config → db+migracje → minio → dyspozytor → HTTP
│   └── internal/
│       ├── config/           # zmienne środowiskowe
│       ├── database/         # pgxpool + migracje (embed)
│       ├── storage/          # klient MinIO (bucket, put/get)
│       ├── notify/           # dyspozytor powiadomień + klient ntfy
│       └── httpapi/          # router chi + handlery per moduł
│           auth, notes, reminders, events, tasks,
│           recipes, mealplan, diary, budget, files, push
└── mobile/                   # Flutter (Dart), Material 3
    └── lib/
        ├── api/              # klient HTTP (JWT, upload plików)
        ├── models/           # modele danych
        ├── screens/          # Dziś, Tydzień, Kuchnia, Budżet, Notatki, ...
        ├── notifications_service.dart  # lokalne alarmy przypomnień
        └── dialogs.dart      # wspólne dialogi dodawania/edycji
```

## Model danych

`users` → posiada: `notes`, `reminders` (z `notified_at` do dedupu push), `events`,
`tasks` (z `repeat`), `recipes` (tagi `TEXT[]`, opcjonalne zdjęcie), `meal_plan`
(unikat na dzień+posiłek, FK do przepisu), `diary_entries`, `budgets` (limit na
miesiąc+kategorię), `transactions` (wydatek/przychód, opcjonalny FK do paragonu),
`files` (metadane obiektów w MinIO), `push_settings` (sekretny temat ntfy +
godzina porannego podsumowania).

## API (skrót)

| Endpoint | Opis |
|---|---|
| `POST /api/auth/register`, `POST /api/auth/login` | konto + token JWT |
| `GET/POST/PUT/DELETE /api/notes[/{id}]` | notatki |
| `... /api/reminders[/{id}]` + `POST .../toggle` | przypomnienia |
| `... /api/events[/{id}]` (`?from=&to=`) | kalendarz |
| `... /api/tasks[/{id}]` + `POST .../toggle` (`?dueFrom=&dueTo=&includeDone=`) | obowiązki (toggle powtarzalnego tworzy następne wystąpienie) |
| `... /api/recipes[/{id}]`, `GET /api/recipes/random?tag=` | przepisy + losowanie obiadu |
| `GET/PUT /api/mealplan`, `DELETE /api/mealplan/{id}` | jadłospis (upsert na dzień+posiłek) |
| `... /api/diary[/{id}]` (`?from=&to=`) | dzienniczek |
| `GET /api/budget/summary?month=`, `PUT /api/budget/limits` | podsumowanie miesiąca + limity |
| `... /api/transactions[/{id}]` (`?month=`) | transakcje |
| `POST /api/files` (multipart), `GET /api/files/{id}` | zdjęcia (MinIO) |
| `GET/PUT /api/push/settings`, `POST /api/push/test`, `POST /api/push/regenerate` | ustawienia push (temat ntfy, godzina podsumowania) |
| `GET /healthz` | status serwera |

Wszystkie endpointy poza `auth` i `healthz` wymagają nagłówka `Authorization: Bearer <token>`.
Komunikaty błędów API są po polsku - aplikacja pokazuje je wprost użytkowniczce.

## Jak uruchomić

### 1. Backend (Docker)

```bash
cp .env.example .env          # opcjonalnie: zmień hasła i JWT_SECRET
docker compose up -d --build
```

- API: `http://localhost:8080` (health-check: `http://localhost:8080/healthz`)
- Konsola MinIO: `http://localhost:9001` (login/hasło z `.env`, domyślnie `minioadmin`/`minioadmin`)
- Postgres: `localhost:5432`
- ntfy (push): `http://localhost:8090`

Backend sam czeka na bazę, wykonuje migracje i zakłada bucket w MinIO.

> Dla push na prawdziwym telefonie ustaw w `.env`
> `NTFY_PUBLIC_URL=http://<IP-komputera>:8090` - to adres, który telefon wpisuje
> w aplikacji ntfy (musi być osiągalny z jego sieci).

### 2. Aplikacja mobilna (Android)

Wymagany [Flutter SDK](https://docs.flutter.dev/get-started/install). Szczegóły w [`mobile/README.md`](mobile/README.md), w skrócie:

```bash
cd mobile
flutter create --project-name ogarniaczka --org pl.apka --platforms android .
# dev po HTTP: dodaj android:usesCleartextTraffic="true" do <application> w
# android/app/src/main/AndroidManifest.xml
# lokalne alarmy przypomnień: włącz desugaring i dodaj odbiorniki w manifeście
# (gotowe snippety w mobile/README.md)
flutter run
```

Adres serwera ustawisz w apce (ikona ⚙️, dostępna też przed zalogowaniem):
- emulator Androida: `http://10.0.2.2:8080` (domyślny),
- prawdziwy telefon: `http://<IP-komputera>:8080` w tej samej sieci Wi-Fi.

## Powiadomienia - jak to działa (bez płatnych usług)

Dwa niezależne poziomy; oba za darmo i bez zewnętrznych dostawców:

1. **Lokalne alarmy w telefonie** (zawsze aktywne, zero konfiguracji).
   Aplikacja przy każdej synchronizacji przypomnień planuje je w systemowym
   AlarmManagerze - dzwonią punktualnie nawet bez internetu i przy zamkniętej apce.

2. **Push przez własny serwer [ntfy](https://ntfy.sh)** (opcjonalny, kontener w compose).
   Backend ma dyspozytor (goroutine, tick co `DISPATCH_INTERVAL_SECONDS`, domyślnie 30 s),
   który publikuje na **sekretny temat użytkownika** (traktuj jak hasło; można go
   zresetować w apce):
   - wymagalne przypomnienia (dokładnie raz; edycja terminu uzbraja je ponownie),
   - poranne podsumowanie obowiązków (raz dziennie o wybranej godzinie, strefa `TIMEZONE`).

   Na telefonie wystarczy darmowa, open-source'owa aplikacja **ntfy**
   (Google Play/F-Droid): dodajesz subskrypcję swojego tematu ze swoim serwerem -
   instrukcja krok po kroku jest w apce w **Ustawienia → Powiadomienia**, razem
   z przyciskiem „Wyślij testowe". Push dochodzi nawet gdy Ogarniaczka jest
   zamknięta, i na dowolną liczbę urządzeń.

   Bez skonfigurowanego `NTFY_URL` backend po prostu pomija publikację -
   lokalne alarmy dalej działają.

### Testy

Skrypt dymny przechodzi całe API - 42 asercje: auth, CRUD-y wszystkich modułów,
powtarzalne obowiązki, upload/pobranie paragonu, izolacja użytkowników oraz
(gdy ntfy działa) pełny obieg push: dostarczenie do ntfy, dedup, podsumowanie,
regeneracja tematu. Wymaga uruchomionego backendu.

## Roadmapa (po MVP)

- 👨‍👩‍👧 konto domowe - współdzielenie list i budżetu z domownikami
- 🧾 OCR paragonów (automatyczne kwoty i kategorie)
- 📈 wykresy budżetu i trendów, eksport CSV
- 📴 tryb offline z synchronizacją
- 🍎 build na iOS (Flutter - ten sam kod)
- 🔐 HTTPS + konta ntfy (deploy poza domową siecią)
