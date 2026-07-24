import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';

/// Wszystkie obowiązki - także te bez terminu i już zrobione.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.i.get('/api/tasks', query: {'includeDone': 'true'});
      if (!mounted) return;
      setState(() {
        _tasks = (res as List).map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _toggle(TaskItem t) async {
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

  Future<void> _delete(TaskItem t) async {
    try {
      await Api.i.delete('/api/tasks/${t.id}');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _tile(TaskItem t) {
    final subtitle = <String>[
      if (t.dueDate != null) prettyDate(t.dueDate!),
      if (t.repeat != 'none') '🔁 ${repeatLabels[t.repeat]?.toLowerCase()}',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Checkbox(value: t.done, onChanged: (_) => _toggle(t)),
        title: Text(
          t.title,
          style: t.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _delete(t),
        ),
        onTap: () async {
          if (await showTaskEditDialog(context, task: t)) _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _tasks.where((t) => !t.done).toList();
    final done = _tasks.where((t) => t.done).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obowiązki ✅', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks-fab',
        onPressed: () async {
          if (await showTaskEditDialog(context)) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (active.isEmpty)
                    const EmptyState(emoji: '🏖️', text: 'Wszystko zrobione.\nCzas na kawę!'),
                  ...active.map(_tile),
                  if (done.isNotEmpty)
                    ExpansionTile(
                      title: Text('Zrobione (${done.length})'),
                      children: done.map(_tile).toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
