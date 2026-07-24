import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../notifications_service.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const TodayScreen({super.key, required this.onLogout});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Reminder> _reminders = [];
  List<TaskItem> _tasks = [];
  List<Event> _events = [];
  List<MealPlanEntry> _meals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final start = dayOnly(DateTime.now());
      final end = start.add(const Duration(days: 1));
      final results = await Future.wait([
        Api.i.get('/api/reminders'),
        Api.i.get('/api/tasks', query: {'includeDone': 'true'}),
        Api.i.get('/api/events', query: {
          'from': start.toUtc().toIso8601String(),
          'to': end.toUtc().toIso8601String(),
        }),
        Api.i.get('/api/mealplan', query: {'from': dateStr(start), 'to': dateStr(start)}),
      ]);
      if (!mounted) return;
      final today = todayStr();
      final allReminders = (results[0] as List)
          .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
          .toList();
      // lokalne alarmy zawsze odpowiadają pełnej liście aktywnych przypomnień
      NotificationsService.i.syncReminders(allReminders);
      setState(() {
        _reminders = allReminders
            .where((r) => r.remindAt.isBefore(end.add(const Duration(days: 2))))
            .toList();
        _tasks = (results[1] as List)
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .where((t) =>
                (!t.done && (t.dueDate == null || t.dueDate!.compareTo(today) <= 0)) ||
                (t.done && t.dueDate == today))
            .toList();
        _events = (results[2] as List).map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
        _meals = (results[3] as List).map((e) => MealPlanEntry.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => mealOrder(a.mealType).compareTo(mealOrder(b.mealType)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final name = Api.i.displayName.isEmpty ? '' : ', ${Api.i.displayName}';
    if (hour < 5) return 'Dobranoc$name 🌙';
    if (hour < 12) return 'Dzień dobry$name ☀️';
    if (hour < 18) return 'Cześć$name 💗';
    return 'Dobry wieczór$name 🌆';
  }

  Future<void> _toggleTask(TaskItem t) async {
    try {
      await Api.i.post('/api/tasks/${t.id}/toggle');
      if (!t.done && t.repeat != 'none' && mounted) {
        showInfo(context, 'Odhaczone! Zaplanowałam kolejny termin 📅');
      }
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggleReminder(Reminder r) async {
    try {
      await Api.i.post('/api/reminders/${r.id}/toggle');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _quickAdd() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Obowiązek'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await showTaskEditDialog(context, initialDue: todayStr())) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Przypomnienie'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await showReminderEditDialog(context)) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Wydarzenie'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await showEventEditDialog(context)) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Posiłek na dziś'),
              onTap: () async {
                Navigator.pop(ctx);
                final recipes = await _fetchRecipes();
                if (!mounted) return;
                if (await showMealPlanEditDialog(context, date: todayStr(), recipes: recipes)) _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Recipe>> _fetchRecipes() async {
    try {
      final res = await Api.i.get('/api/recipes');
      return (res as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(
              DateFormat('EEEE, d MMMM', 'pl').format(now),
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wszystkie obowiązki',
            icon: const Icon(Icons.checklist_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
              _load();
            },
          ),
          IconButton(
            tooltip: 'Przypomnienia',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
              _load();
            },
          ),
          IconButton(
            tooltip: 'Ustawienia',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(onLogout: widget.onLogout)),
              );
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _quickAdd,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (_reminders.isNotEmpty) ...[
                    const SectionHeader('🔔 Przypomnienia'),
                    Card(
                      child: Column(
                        children: _reminders
                            .map((r) => CheckboxListTile(
                                  value: r.done,
                                  onChanged: (_) => _toggleReminder(r),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(r.title),
                                  subtitle: Text(
                                    prettyDateTime(r.remindAt),
                                    style: TextStyle(
                                      color: r.remindAt.isBefore(DateTime.now())
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SectionHeader('✅ Obowiązki na dziś'),
                  Card(
                    child: _tasks.isEmpty
                        ? const EmptyState(emoji: '🎉', text: 'Nic do zrobienia - możesz odpocząć!')
                        : Column(
                            children: _tasks
                                .map((t) => CheckboxListTile(
                                      value: t.done,
                                      onChanged: (_) => _toggleTask(t),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      title: Text(
                                        t.title,
                                        style: t.done
                                            ? const TextStyle(decoration: TextDecoration.lineThrough)
                                            : null,
                                      ),
                                      subtitle: t.dueDate != null && t.dueDate!.compareTo(todayStr()) < 0
                                          ? Text('zaległe od ${prettyDate(t.dueDate!)}',
                                              style: TextStyle(color: Theme.of(context).colorScheme.error))
                                          : null,
                                    ))
                                .toList(),
                          ),
                  ),
                  const SectionHeader('📅 Dzisiejsze wydarzenia'),
                  Card(
                    child: _events.isEmpty
                        ? const EmptyState(emoji: '🛋️', text: 'Kalendarz na dziś jest pusty')
                        : Column(
                            children: _events
                                .map((e) => ListTile(
                                      leading: Text(
                                        e.allDay ? '📌' : timeOf(e.startsAt),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      title: Text(e.title),
                                      subtitle: e.description.isEmpty ? null : Text(e.description),
                                    ))
                                .toList(),
                          ),
                  ),
                  const SectionHeader('🍽️ Dziś jemy'),
                  Card(
                    child: _meals.isEmpty
                        ? const EmptyState(emoji: '🤔', text: 'Nie zaplanowano posiłków.\nZajrzyj do Kuchni!')
                        : Column(
                            children: _meals
                                .map((m) => ListTile(
                                      leading: Text(mealTypeEmoji[m.mealType] ?? '🍽️',
                                          style: const TextStyle(fontSize: 24)),
                                      title: Text(m.recipeTitle ?? m.note),
                                      subtitle: Text(mealTypeLabels[m.mealType] ?? m.mealType),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
