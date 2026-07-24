import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api/api_client.dart';
import 'models/models.dart';
import 'util.dart';
import 'widgets/common.dart';

/// Wybór zdjęcia: aparat albo galeria. Zwraca null gdy anulowano.
Future<File?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Zrób zdjęcie'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Wybierz z galerii'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 82);
  return picked == null ? null : File(picked.path);
}

/// Dialog dodawania/edycji obowiązku. Zwraca true, gdy coś zapisano.
Future<bool> showTaskEditDialog(BuildContext context, {TaskItem? task, String? initialDue}) async {
  final title = TextEditingController(text: task?.title ?? '');
  String? due = task?.dueDate ?? initialDue;
  String repeat = task?.repeat ?? 'none';

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(task == null ? 'Nowy obowiązek' : 'Edytuj obowiązek'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: task == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Co jest do zrobienia?', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(due == null ? 'Bez terminu' : prettyDate(due!)),
                trailing: due == null
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setLocal(() => due = null)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: due == null ? DateTime.now() : DateTime.parse(due!),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setLocal(() => due = dateStr(picked));
                },
              ),
              DropdownButtonFormField<String>(
                value: repeat,
                decoration: const InputDecoration(labelText: 'Powtarzanie', border: OutlineInputBorder()),
                items: repeatLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setLocal(() => repeat = v ?? 'none'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    ),
  );

  if (saved != true || title.text.trim().isEmpty) return false;
  final body = {
    'title': title.text.trim(),
    'notes': task?.notes ?? '',
    'dueDate': due,
    'repeat': repeat,
  };
  try {
    if (task == null) {
      await Api.i.post('/api/tasks', body: body);
    } else {
      await Api.i.put('/api/tasks/${task.id}', body: body);
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Dialog dodawania/edycji przypomnienia.
Future<bool> showReminderEditDialog(BuildContext context, {Reminder? reminder}) async {
  final title = TextEditingController(text: reminder?.title ?? '');
  DateTime date = reminder?.remindAt ?? DateTime.now().add(const Duration(hours: 1));
  TimeOfDay time = TimeOfDay.fromDateTime(date);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(reminder == null ? 'Nowe przypomnienie' : 'Edytuj przypomnienie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: reminder == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'O czym Ci przypomnieć?', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(time.format(ctx)),
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: time);
                if (picked != null) setLocal(() => time = picked);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    ),
  );

  if (saved != true || title.text.trim().isEmpty) return false;
  final remindAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final body = {
    'title': title.text.trim(),
    'remindAt': remindAt.toUtc().toIso8601String(),
  };
  try {
    if (reminder == null) {
      await Api.i.post('/api/reminders', body: body);
    } else {
      await Api.i.put('/api/reminders/${reminder.id}', body: body);
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Dialog dodawania/edycji wydarzenia w kalendarzu.
Future<bool> showEventEditDialog(BuildContext context, {Event? event, DateTime? initialDate}) async {
  final title = TextEditingController(text: event?.title ?? '');
  final description = TextEditingController(text: event?.description ?? '');
  DateTime date = dayOnly(event?.startsAt ?? initialDate ?? DateTime.now());
  bool allDay = event?.allDay ?? false;
  TimeOfDay time = event == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay.fromDateTime(event.startsAt);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(event == null ? 'Nowe wydarzenie' : 'Edytuj wydarzenie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: event == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Co się dzieje?', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Szczegóły (opcjonalnie)', border: OutlineInputBorder()),
              ),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cały dzień'),
                value: allDay,
                onChanged: (v) => setLocal(() => allDay = v),
              ),
              if (!allDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(time.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: time);
                    if (picked != null) setLocal(() => time = picked);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    ),
  );

  if (saved != true || title.text.trim().isEmpty) return false;
  final startsAt = allDay
      ? DateTime(date.year, date.month, date.day)
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final body = {
    'title': title.text.trim(),
    'description': description.text.trim(),
    'startsAt': startsAt.toUtc().toIso8601String(),
    'allDay': allDay,
  };
  try {
    if (event == null) {
      await Api.i.post('/api/events', body: body);
    } else {
      await Api.i.put('/api/events/${event.id}', body: body);
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Dialog planowania posiłku: przepis z bazy albo dowolny wpis.
Future<bool> showMealPlanEditDialog(
  BuildContext context, {
  required String date,
  MealPlanEntry? entry,
  required List<Recipe> recipes,
}) async {
  String mealType = entry?.mealType ?? 'obiad';
  // '' oznacza "bez przepisu" (sentinel zamiast null - dropdown z nullem
  // pokazywałby pustą wartość zamiast etykiety).
  String recipeChoice = entry?.recipeId ?? '';
  final note = TextEditingController(text: entry?.note ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Posiłek - ${prettyDate(date)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(labelText: 'Posiłek', border: OutlineInputBorder()),
                items: mealTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text('${mealTypeEmoji[t]} ${mealTypeLabels[t]}')))
                    .toList(),
                onChanged: entry == null ? (v) => setLocal(() => mealType = v ?? 'obiad') : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: recipeChoice,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Przepis z Twojej bazy', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— bez przepisu —')),
                  ...recipes.map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.title, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setLocal(() => recipeChoice = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Albo wpisz, co jecie',
                  hintText: 'np. pierogi od mamy',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    ),
  );

  if (saved != true) return false;
  try {
    await Api.i.put('/api/mealplan', body: {
      'date': date,
      'mealType': mealType,
      'recipeId': recipeChoice.isEmpty ? null : recipeChoice,
      'note': note.text.trim(),
    });
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Dialog wpisu do dzienniczka żywieniowego.
Future<bool> showDiaryEditDialog(BuildContext context, {required String date, DiaryEntry? entry}) async {
  String mealType = entry?.mealType ?? 'sniadanie';
  final description = TextEditingController(text: entry?.description ?? '');
  final calories = TextEditingController(text: entry?.calories?.toString() ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Co zjadłaś? - ${prettyDate(date)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(labelText: 'Posiłek', border: OutlineInputBorder()),
                items: mealTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text('${mealTypeEmoji[t]} ${mealTypeLabels[t]}')))
                    .toList(),
                onChanged: (v) => setLocal(() => mealType = v ?? 'sniadanie'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                autofocus: entry == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calories,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kalorie (opcjonalnie)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    ),
  );

  if (saved != true || description.text.trim().isEmpty) return false;
  final body = {
    'date': date,
    'mealType': mealType,
    'description': description.text.trim(),
    'calories': int.tryParse(calories.text.trim()),
  };
  try {
    if (entry == null) {
      await Api.i.post('/api/diary', body: body);
    } else {
      await Api.i.put('/api/diary/${entry.id}', body: body);
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}
