import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'recipe_edit_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.i.get('/api/recipes/${widget.recipeId}');
      if (!mounted) return;
      setState(() => _recipe = Recipe.fromJson(res as Map<String, dynamic>));
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      Navigator.pop(context);
    }
  }

  Future<void> _planIt() async {
    final r = _recipe;
    if (r == null) return;
    DateTime date = DateTime.now();
    String mealType = 'obiad';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Dodaj do jadłospisu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(prettyDate(dateStr(date))),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(labelText: 'Posiłek', border: OutlineInputBorder()),
                items: mealTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text('${mealTypeEmoji[t]} ${mealTypeLabels[t]}')))
                    .toList(),
                onChanged: (v) => setLocal(() => mealType = v ?? 'obiad'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zaplanuj')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await Api.i.put('/api/mealplan', body: {
        'date': dateStr(date),
        'mealType': mealType,
        'recipeId': r.id,
        'note': '',
      });
      if (mounted) showInfo(context, 'Zaplanowane! 🍽️');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.title ?? '...', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: r == null
                ? null
                : () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r)),
                    );
                    if (changed == true) _load();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: r == null
                ? null
                : () async {
                    if (!await confirmDelete(context, 'Przepis "${r.title}" zniknie na zawsze.')) return;
                    try {
                      await Api.i.delete('/api/recipes/${r.id}');
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) showError(context, e);
                    }
                  },
          ),
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (r.imageFileId != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      Api.i.fileUrl(r.imageFileId!),
                      headers: Api.i.imageHeaders,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (r.timeMinutes != null)
                      Chip(visualDensity: VisualDensity.compact, label: Text('⏱️ ${r.timeMinutes} min')),
                    if (r.servings != null)
                      Chip(visualDensity: VisualDensity.compact, label: Text('👥 ${r.servings} porcje')),
                    ...r.tags.map((t) => Chip(visualDensity: VisualDensity.compact, label: Text('#$t'))),
                  ],
                ),
                if (r.description.isNotEmpty) ...[
                  const SectionHeader('Opis'),
                  Text(r.description),
                ],
                if (r.ingredients.isNotEmpty) ...[
                  const SectionHeader('🛒 Składniki'),
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(r.ingredients))),
                ],
                if (r.steps.isNotEmpty) ...[
                  const SectionHeader('👩‍🍳 Przygotowanie'),
                  Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(r.steps))),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _planIt,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Dodaj do jadłospisu'),
                ),
              ],
            ),
    );
  }
}
