# Uruchomienie na Windows 🪟

## Backend (Docker)

1. Zainstaluj [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) (z backendem WSL 2 - instalator ustawia to domyślnie).
2. W katalogu repo (PowerShell):

   ```powershell
   copy .env.example .env
   docker compose up -d --build
   ```

3. Sprawdź: <http://localhost:8080/healthz> - API, `:9001` - konsola MinIO, `:8090` - ntfy (push).

## Aplikacja mobilna (Android)

1. Zainstaluj [Flutter SDK dla Windows](https://docs.flutter.dev/get-started/install/windows) i Android Studio (SDK + emulator). Zweryfikuj: `flutter doctor`.
2. Uruchom:

   ```powershell
   cd mobile
   flutter pub get
   flutter run
   ```

3. Adres serwera (ikona ⚙️ w apce):
   - **emulator**: domyślny `http://10.0.2.2:8080` działa od razu,
   - **prawdziwy telefon**: ta sama sieć Wi-Fi + `http://<IP-komputera>:8080` (IP sprawdzisz przez `ipconfig`). Przy pierwszym starcie zezwól Dockerowi na dostęp w zaporze Windows albo dodaj reguły ręcznie (PowerShell jako administrator):

     ```powershell
     netsh advfirewall firewall add rule name="Ogarniaczka API"  dir=in action=allow protocol=TCP localport=8080
     netsh advfirewall firewall add rule name="Ogarniaczka ntfy" dir=in action=allow protocol=TCP localport=8090
     ```

## Push na telefon (opcjonalnie)

W `.env` ustaw `NTFY_PUBLIC_URL=http://<IP-komputera>:8090`, przeładuj compose (`docker compose up -d`), a na telefonie skonfiguruj aplikację ntfy według instrukcji z **Ustawienia → Powiadomienia** w Ogarniaczce.

## Smoke test (opcjonalnie)

Skrypt jest bashowy - odpal w **Git Bash** albo **WSL**:

```bash
bash backend/scripts/smoke.sh
```

(wymaga `curl` i `python3`; w czystym PowerShellu nie zadziała).
