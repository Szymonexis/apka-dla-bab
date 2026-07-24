import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: Api.i.baseUrl);
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          if (Api.i.isLoggedIn) ...[
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
          ],
        ],
      ),
    );
  }
}
