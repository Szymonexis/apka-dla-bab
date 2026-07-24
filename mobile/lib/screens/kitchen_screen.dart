import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kuchnia 🍳', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [
            Tab(text: 'Przepisy'),
            Tab(text: 'Jadłospis'),
            Tab(text: 'Dzienniczek'),
          ]),
        ),
        body: const TabBarView(
          children: [RecipesTab(), MealPlanTab(), DiaryTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Przepisy

class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  List<Recipe> _recipes = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.i.get('/api/recipes');
      if (!mounted) return;
      setState(() {
        _recipes = (res as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _toggleFavorite(Recipe r) async {
    try {
      r.favorite = !r.favorite;
      await Api.i.put('/api/recipes/${r.id}', body: r.toJson());
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _randomIdea() async {
    try {
      final res = await Api.i.get('/api/recipes/random');
      final recipe = Recipe.fromJson(res as Map<String, dynamic>);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pomysł na obiad 🎲'),
          content: Text(
            recipe.timeMinutes == null
                ? recipe.title
                : '${recipe.title}\n⏱️ ok. ${recipe.timeMinutes} min',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
                );
                _load();
              },
              child: const Text('Zobacz przepis'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await Api.i.put('/api/mealplan', body: {
                    'date': todayStr(),
                    'mealType': 'obiad',
                    'recipeId': recipe.id,
                    'note': '',
                  });
                  if (mounted) showInfo(context, 'Zaplanowane na dziś! 🍽️');
                } catch (e) {
                  if (mounted) showError(context, e);
                }
              },
              child: const Text('Na dziś!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _recipes
        : _recipes
            .where((r) =>
                r.title.toLowerCase().contains(_search.toLowerCase()) ||
                r.tags.any((t) => t.toLowerCase().contains(_search.toLowerCase())))
            .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipes-fab',
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const RecipeEditScreen()),
          );
          if (changed == true) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: const InputDecoration(
                            hintText: 'Szukaj przepisu lub tagu...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _randomIdea,
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Wylosuj'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const EmptyState(
                        emoji: '👩‍🍳',
                        text: 'Brak przepisów.\nDodaj pierwszy plusem na dole!'),
                  ...filtered.map((r) => Card(
                        child: ListTile(
                          leading: r.imageFileId != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    Api.i.fileUrl(r.imageFileId!),
                                    headers: Api.i.imageHeaders,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Text('🍲', style: TextStyle(fontSize: 30)),
                                  ),
                                )
                              : const Text('🍲', style: TextStyle(fontSize: 30)),
                          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if (r.timeMinutes != null) '⏱️ ${r.timeMinutes} min',
                              if (r.tags.isNotEmpty) r.tags.join(', '),
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              r.favorite ? Icons.favorite : Icons.favorite_border,
                              color: r.favorite ? Theme.of(context).colorScheme.primary : null,
                            ),
                            onPressed: () => _toggleFavorite(r),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)),
                            );
                            _load();
                          },
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------- Jadłospis

class MealPlanTab extends StatefulWidget {
  const MealPlanTab({super.key});

  @override
  State<MealPlanTab> createState() => _MealPlanTabState();
}

class _MealPlanTabState extends State<MealPlanTab> {
  int _weekOffset = 0;
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
      final results = await Future.wait([
        Api.i.get('/api/mealplan', query: {'from': dateStr(monday), 'to': dateStr(sunday)}),
        Api.i.get('/api/recipes'),
      ]);
      if (!mounted) return;
      setState(() {
        _meals = (results[0] as List).map((e) => MealPlanEntry.fromJson(e as Map<String, dynamic>)).toList();
        _recipes = (results[1] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _delete(MealPlanEntry m) async {
    try {
      await Api.i.delete('/api/mealplan/${m.id}');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monday = _monday;
    final sunday = monday.add(const Duration(days: 6));
    return Column(
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
                    children: List.generate(7, (i) {
                      final day = monday.add(Duration(days: i));
                      final ds = dateStr(day);
                      final dayMeals = _meals.where((m) => m.date == ds).toList()
                        ..sort((a, b) => mealOrder(a.mealType).compareTo(mealOrder(b.mealType)));
                      final isToday = ds == todayStr();
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isToday
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.45)
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                DateFormat('EEEE, d.MM', 'pl').format(day),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () async {
                                  if (await showMealPlanEditDialog(context, date: ds, recipes: _recipes)) {
                                    _load();
                                  }
                                },
                              ),
                            ),
                            ...dayMeals.map((m) => ListTile(
                                  dense: true,
                                  leading: Text(mealTypeEmoji[m.mealType] ?? '🍽️',
                                      style: const TextStyle(fontSize: 22)),
                                  title: Text(m.recipeTitle ?? m.note),
                                  subtitle: Text(mealTypeLabels[m.mealType] ?? m.mealType),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => _delete(m),
                                  ),
                                  onTap: () async {
                                    if (await showMealPlanEditDialog(context,
                                        date: ds, entry: m, recipes: _recipes)) {
                                      _load();
                                    }
                                  },
                                )),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Dzienniczek

class DiaryTab extends StatefulWidget {
  const DiaryTab({super.key});

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  DateTime _date = dayOnly(DateTime.now());
  List<DiaryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ds = dateStr(_date);
      final res = await Api.i.get('/api/diary', query: {'from': ds, 'to': ds});
      if (!mounted) return;
      setState(() {
        _entries = (res as List).map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => mealOrder(a.mealType).compareTo(mealOrder(b.mealType)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  void _shiftDay(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  Future<void> _delete(DiaryEntry e) async {
    try {
      await Api.i.delete('/api/diary/${e.id}');
      await _load();
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _entries.fold<int>(0, (sum, e) => sum + (e.calories ?? 0));
    final isToday = dateStr(_date) == todayStr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'diary-fab',
        onPressed: () async {
          if (await showDiaryEditDialog(context, date: dateStr(_date))) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftDay(-1)),
              Text(
                DateFormat('EEEE, d MMM', 'pl').format(_date),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftDay(1)),
              if (!isToday)
                TextButton(
                  onPressed: () {
                    setState(() => _date = dayOnly(DateTime.now()));
                    _load();
                  },
                  child: const Text('Dziś'),
                ),
            ],
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Text('🔥', style: TextStyle(fontSize: 26)),
              title: Text('$totalKcal kcal', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('suma z wpisów tego dnia'),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        if (_entries.isEmpty)
                          const EmptyState(emoji: '🥣', text: 'Brak wpisów.\nDodaj plusem, co zjadłaś!'),
                        ..._entries.map((e) => Card(
                              child: ListTile(
                                leading: Text(mealTypeEmoji[e.mealType] ?? '🍽️',
                                    style: const TextStyle(fontSize: 24)),
                                title: Text(e.description),
                                subtitle: Text([
                                  mealTypeLabels[e.mealType] ?? e.mealType,
                                  if (e.calories != null) '${e.calories} kcal',
                                ].join(' · ')),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _delete(e),
                                ),
                                onTap: () async {
                                  if (await showDiaryEditDialog(context, date: e.date, entry: e)) {
                                    _load();
                                  }
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
