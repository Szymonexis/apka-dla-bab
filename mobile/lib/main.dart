import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api/api_client.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');
  await Api.i.init();
  runApp(const OgarniaczkaApp());
}

class OgarniaczkaApp extends StatefulWidget {
  const OgarniaczkaApp({super.key});

  @override
  State<OgarniaczkaApp> createState() => _OgarniaczkaAppState();
}

class _OgarniaczkaAppState extends State<OgarniaczkaApp> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFD81B60));
    return MaterialApp(
      title: 'Ogarniaczka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFF7F9),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFFFF7F9),
          foregroundColor: scheme.onSurface,
          elevation: 0,
        ),
      ),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Api.i.isLoggedIn
          ? HomeShell(onLogout: _refresh)
          : LoginScreen(onLoggedIn: _refresh),
    );
  }
}
