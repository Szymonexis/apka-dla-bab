import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';

/// Plan tygodnia: wydarzenia + obowiązki + jadłospis dzień po dniu.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _weekOffset = 0;
  List<Event> _events = [];
  List<TaskItem> _tasks = [];
  List<MealPlanEntry> _meals = [];
  List<Recipe> _recipes = [];
  bool _loading = true;

  DateTime get _monday => mondayOf(DateTime.now()).add(Duration(days: 7 * _weekOffset));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final monday = _monday;
      final sunday = monday.add(const Duration(days: 6));
      final end = monday.add(const Duration(days: 7));
      final results = await Future.wait([
        Api.i.get('/api/events', query: {
          'from': monday.toUtc().toIso8601String(),
          'to': end.toUtc().toIso8601String(),
        }),
        Api.i.get('/api/tasks', query: {
          'includeDone': 'true',
          'dueFrom': dateStr(monday),
          'dueTo': dateStr(sunday),
        }),
        Api.i.get('/api/mealplan', query: {'from': dateStr(monday), 'to': dateStr(sunday)}),
        Api.i.get('/api/recipes'),
      ]);
      if (!mounted) return;
      setState(() {
        _events = (results[0] as List).map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
        _tasks = (results[1] as List).map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
        _meals = (results[2] as List).map((e) => MealPlanEntry.fromJson(e as Map<String, dynamic>)).toList();
        _recipes = (results[3] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _toggleTask(TaskItem t) async {
    try {
      await Api.i.post('/api/tasks/${t.id}/toggle');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _addForDay(DateTime day) {
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
                if (await showTaskEditDialog(context, initialDue: dateStr(day))) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Wydarzenie'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await showEventEditDialog(context, initialDate: day)) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Posiłek'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await showMealPlanEditDialog(context, date: dateStr(day), recipes: _recipes)) {
                  _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(DateTime day) {
    final ds = dateStr(day);
    final isToday = ds == todayStr();
    final events = _events.where((e) => dateStr(e.startsAt) == ds).toList();
    final tasks = _tasks.where((t) => t.dueDate == ds).toList();
    final meals = _meals.where((m) => m.date == ds).toList()
      ..sort((a, b) => mealOrder(a.mealType).compareTo(mealOrder(b.mealType)));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isToday ? scheme.primaryContainer.withOpacity(0.45) : scheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d.MM', 'pl').format(day),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isToday ? scheme.primary : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Dodaj na ten dzień',
                  onPressed: () => _addForDay(day),
                ),
              ],
            ),
            if (events.isEmpty && tasks.isEmpty && meals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('nic nie zaplanowano', style: TextStyle(color: scheme.outline, fontSize: 13)),
              ),
            if (meals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: meals
                      .map((m) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${mealTypeEmoji[m.mealType]} ${m.recipeTitle ?? m.note}',
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
              ),
            ...events.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(e.allDay ? '📌' : timeOf(e.startsAt),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.title)),
                    ],
                  ),
                )),
            ...tasks.map((t) => InkWell(
                  onTap: () => _toggleTask(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 20,
                          color: t.done ? scheme.primary : scheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.title,
                            style: t.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monday = _monday;
    final sunday = monday.add(const Duration(days: 6));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan tygodnia 🗓️', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_weekOffset != 0)
            TextButton(
              onPressed: () {
                setState(() => _weekOffset = 0);
                _load();
              },
              child: const Text('Dziś'),
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _weekOffset--);
                  _load();
                },
              ),
              Text(
                '${DateFormat('d MMM', 'pl').format(monday)} – ${DateFormat('d MMM', 'pl').format(sunday)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _weekOffset++);
                  _load();
                },
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: List.generate(7, (i) => _dayCard(monday.add(Duration(days: i)))),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
