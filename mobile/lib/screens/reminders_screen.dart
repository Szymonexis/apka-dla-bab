import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../notifications_service.dart';
import '../util.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.i.get('/api/reminders', query: {'includeDone': 'true'});
      if (!mounted) return;
      final reminders =
          (res as List).map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
      NotificationsService.i.syncReminders(reminders);
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _toggle(Reminder r) async {
    try {
      await Api.i.post('/api/reminders/${r.id}/toggle');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Reminder r) async {
    try {
      await Api.i.delete('/api/reminders/${r.id}');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _tile(Reminder r) {
    final overdue = !r.done && r.remindAt.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        leading: Checkbox(value: r.done, onChanged: (_) => _toggle(r)),
        title: Text(
          r.title,
          style: r.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text(
          prettyDateTime(r.remindAt),
          style: overdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _delete(r),
        ),
        onTap: () async {
          if (await showReminderEditDialog(context, reminder: r)) _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _reminders.where((r) => !r.done).toList();
    final done = _reminders.where((r) => r.done).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Przypomnienia 🔔', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'reminders-fab',
        onPressed: () async {
          if (await showReminderEditDialog(context)) _load();
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
                    const EmptyState(emoji: '🔕', text: 'Żadnych przypomnień.\nGłowa wolna!'),
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
