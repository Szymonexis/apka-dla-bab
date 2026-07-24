import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models/models.dart';

/// Lokalne powiadomienia: przypomnienia dzwonią na telefonie o właściwej porze
/// nawet bez internetu i przy zamkniętej aplikacji (AlarmManager Androida).
/// To pierwszy poziom powiadomień - zero infrastruktury. Drugi (opcjonalny)
/// to push przez self-hostowany ntfy, obsługiwany w całości przez backend.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService i = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission(); // Android 13+
    await android?.requestExactAlarmsPermission(); // Android 12+ (dokładne alarmy)
    _ready = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'przypomnienia',
      'Przypomnienia',
      channelDescription: 'Przypomnienia z Ogarniaczki',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  /// Przeplanowuje alarmy tak, by odpowiadały aktualnej liście przypomnień.
  /// Wołane po każdym pobraniu/zmianie przypomnień - stan alarmów zawsze
  /// odzwierciedla serwer. Awaria powiadomień nie może wywalić aplikacji,
  /// stąd szerokie catche.
  Future<void> syncReminders(List<Reminder> reminders) async {
    try {
      await init();
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final r in reminders) {
        if (r.done || !r.remindAt.isAfter(now)) continue;
        // Planujemy w UTC: to absolutny moment w czasie, więc etykieta strefy
        // nie ma znaczenia i nie potrzebujemy wykrywania strefy telefonu.
        final when = tz.TZDateTime.from(r.remindAt.toUtc(), tz.UTC);
        try {
          await _plugin.zonedSchedule(
            _idFor(r.id),
            'Przypomnienie 🔔',
            r.title,
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } on PlatformException {
          // brak zgody na dokładne alarmy -> tryb przybliżony (± kilka minut)
          await _plugin.zonedSchedule(
            _idFor(r.id),
            'Przypomnienie 🔔',
            r.title,
            when,
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {
      // powiadomienia to dodatek - cicho ignorujemy (np. brak zgody użytkownika)
    }
  }

  /// Stabilne 31-bitowe ID alarmu wyliczone z UUID przypomnienia.
  int _idFor(String uuid) => uuid.hashCode & 0x7fffffff;
}
