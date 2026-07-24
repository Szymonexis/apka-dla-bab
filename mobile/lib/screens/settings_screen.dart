import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const SettingsScreen({super.key, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;

  // ustawienia push (ntfy) - ładowane tylko po zalogowaniu
  bool _pushLoaded = false;
  bool _pushEnabled = false;
  String _pushServer = '';
  String _pushTopic = '';
  int _digestHour = 8;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: Api.i.baseUrl);
    if (Api.i.isLoggedIn) _loadPush();
  }

  Future<void> _loadPush() async {
    try {
      final res = await Api.i.get('/api/push/settings');
      if (!mounted) return;
      final map = res as Map<String, dynamic>;
      setState(() {
        _pushLoaded = true;
        _pushEnabled = (map['enabled'] ?? false) as bool;
        _pushServer = (map['serverUrl'] ?? '') as String;
        _pushTopic = (map['topic'] ?? '') as String;
        _digestHour = (map['digestHour'] ?? 8) as int;
      });
    } catch (_) {
      // sekcja push po prostu się nie pokaże
    }
  }

  Future<void> _saveUrl() async {
    await Api.i.setBaseUrl(_url.text);
    if (mounted) {
      _url.text = Api.i.baseUrl;
      showInfo(context, 'Zapisano adres serwera');
    }
  }

  Future<void> _testConnection() async {
    await Api.i.setBaseUrl(_url.text);
    try {
      await Api.i.get('/healthz');
      if (mounted) showInfo(context, 'Połączenie działa! 🎉');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _setDigestHour(int hour) async {
    try {
      await Api.i.put('/api/push/settings', body: {'digestHour': hour});
      setState(() => _digestHour = hour);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _testPush() async {
    try {
      await Api.i.post('/api/push/test');
      if (mounted) showInfo(context, 'Wysłane! Sprawdź powiadomienie z ntfy 🎉');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _regenerateTopic() async {
    final sure = await confirmDelete(context,
        'Stary temat przestanie działać - trzeba będzie zmienić subskrypcję w aplikacji ntfy.');
    if (!sure) return;
    try {
      final res = await Api.i.post('/api/push/regenerate');
      if (!mounted) return;
      setState(() => _pushTopic = ((res as Map<String, dynamic>)['topic'] ?? '') as String);
      showInfo(context, 'Wygenerowano nowy temat');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showInfo(context, 'Skopiowano $label');
  }

  Future<void> _logout() async {
    await Api.i.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia ⚙️', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('🌐 Serwer'),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Adres serwera',
              hintText: 'http://10.0.2.2:8080',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Sprawdź połączenie'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _saveUrl, child: const Text('Zapisz')),
            ],
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Podpowiedź 💡\n\n'
                '• Emulator Androida: http://10.0.2.2:8080\n'
                '• Prawdziwy telefon: adres IP komputera z backendem\n'
                '  w tej samej sieci Wi-Fi, np. http://192.168.1.20:8080',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          if (Api.i.isLoggedIn) ...[
            const SectionHeader('🔔 Powiadomienia'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Przypomnienia dzwonią na tym telefonie automatycznie '
                  '(lokalne alarmy - działają bez internetu). Poniższy push przez '
                  'Twój własny serwer ntfy to opcjonalny dodatek: dociera nawet '
                  'wtedy, gdy Ogarniaczka jest zamknięta, i na inne urządzenia.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            if (_pushLoaded && !_pushEnabled)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Serwer push (ntfy) nie jest skonfigurowany na backendzie.\n'
                    'Uruchom kontener ntfy z docker-compose i ustaw NTFY_URL.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            if (_pushLoaded && _pushEnabled) ...[
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: const Text('Serwer ntfy'),
                      subtitle: Text(_pushServer),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () => _copy('adres serwera', _pushServer),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: const Text('Twój sekretny temat'),
                      subtitle: Text(_pushTopic, style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () => _copy('temat', _pushTopic),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('Poranne podsumowanie obowiązków'),
                      trailing: DropdownButton<int>(
                        value: _digestHour,
                        items: [
                          const DropdownMenuItem(value: -1, child: Text('wyłączone')),
                          for (var h = 5; h <= 12; h++)
                            DropdownMenuItem(value: h, child: Text('$h:00')),
                        ],
                        onChanged: (v) {
                          if (v != null) _setDigestHour(v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testPush,
                              icon: const Icon(Icons.send_outlined, size: 18),
                              label: const Text('Wyślij testowe'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _regenerateTopic,
                              icon: const Icon(Icons.autorenew, size: 18),
                              label: const Text('Nowy temat'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Jak włączyć push na telefonie 📲\n\n'
                    '1. Zainstaluj darmową aplikację "ntfy" (Google Play lub F-Droid).\n'
                    '2. W ntfy: Dodaj subskrypcję → wpisz temat skopiowany powyżej.\n'
                    '3. W "Użyj innego serwera" podaj adres serwera ntfy z tej strony.\n'
                    '4. Kliknij "Wyślij testowe" i sprawdź, czy przyszło. 🎉\n\n'
                    'Temat traktuj jak hasło - kto go zna, może czytać Twoje powiadomienia.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            const SectionHeader('👤 Konto'),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(Api.i.displayName.isEmpty ? 'Zalogowano' : Api.i.displayName),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.logout),
              label: const Text('Wyloguj się'),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
