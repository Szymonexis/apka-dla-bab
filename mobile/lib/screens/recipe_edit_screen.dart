import 'dart:io';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe? recipe;
  const RecipeEditScreen({super.key, this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _ingredients;
  late final TextEditingController _steps;
  late final TextEditingController _tags;
  late final TextEditingController _time;
  late final TextEditingController _servings;
  late bool _favorite;
  String? _imageFileId;
  File? _pickedImage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _title = TextEditingController(text: r?.title ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _ingredients = TextEditingController(text: r?.ingredients ?? '');
    _steps = TextEditingController(text: r?.steps ?? '');
    _tags = TextEditingController(text: r?.tags.join(', ') ?? '');
    _time = TextEditingController(text: r?.timeMinutes?.toString() ?? '');
    _servings = TextEditingController(text: r?.servings?.toString() ?? '');
    _favorite = r?.favorite ?? false;
    _imageFileId = r?.imageFileId;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Przepis musi mieć nazwę');
      return;
    }
    setState(() => _busy = true);
    try {
      var imageId = _imageFileId;
      if (_pickedImage != null) {
        imageId = await Api.i.uploadFile(_pickedImage!);
      }
      final body = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'ingredients': _ingredients.text.trim(),
        'steps': _steps.text.trim(),
        'tags': _tags.text
            .split(',')
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList(),
        'timeMinutes': int.tryParse(_time.text.trim()),
        'servings': int.tryParse(_servings.text.trim()),
        'favorite': _favorite,
        'imageFileId': imageId,
      };
      if (widget.recipe == null) {
        await Api.i.post('/api/recipes', body: body);
      } else {
        await Api.i.put('/api/recipes/${widget.recipe!.id}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Nowy przepis' : 'Edytuj przepis',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _busy ? null : _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nazwa *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Krótki opis', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _time,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Czas (min)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _servings,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Porcje', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tagi (po przecinku)',
              hintText: 'obiad, szybkie, wege',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ingredients,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Składniki (każdy w nowej linii)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _steps,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Przygotowanie',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (_pickedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_pickedImage!, height: 180, fit: BoxFit.cover),
            )
          else if (_imageFileId != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                Api.i.fileUrl(_imageFileId!),
                headers: Api.i.imageHeaders,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await pickPhoto(context);
                    if (f != null) setState(() => _pickedImage = f);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Zdjęcie'),
                ),
              ),
              if (_pickedImage != null || _imageFileId != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _pickedImage = null;
                    _imageFileId = null;
                  }),
                  child: const Text('Usuń zdjęcie'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Zapisz przepis'),
          ),
        ],
      ),
    );
  }
}
