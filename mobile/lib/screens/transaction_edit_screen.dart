import 'dart:io';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../dialogs.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';

class TransactionEditScreen extends StatefulWidget {
  final Tx? tx;
  const TransactionEditScreen({super.key, this.tx});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  late String _kind;
  late String _category;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _description;
  String? _receiptFileId;
  File? _pickedReceipt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tx;
    _kind = t?.kind ?? 'expense';
    _category = t?.category ?? 'jedzenie';
    _date = t == null ? DateTime.now() : DateTime.parse(t.occurredOn);
    _amount = TextEditingController(
        text: t == null ? '' : (t.amountGrosze / 100).toStringAsFixed(2).replaceAll('.', ','));
    _description = TextEditingController(text: t?.description ?? '');
    _receiptFileId = t?.receiptFileId;
  }

  Future<void> _save() async {
    final grosze = parseMoney(_amount.text);
    if (grosze == null || grosze <= 0) {
      showError(context, 'Podaj prawidłową kwotę, np. 24,99');
      return;
    }
    setState(() => _busy = true);
    try {
      var receiptId = _receiptFileId;
      if (_pickedReceipt != null) {
        receiptId = await Api.i.uploadFile(_pickedReceipt!);
      }
      final body = {
        'occurredOn': dateStr(_date),
        'kind': _kind,
        'amountGrosze': grosze,
        'category': _category,
        'description': _description.text.trim(),
        'receiptFileId': receiptId,
      };
      if (widget.tx == null) {
        await Api.i.post('/api/transactions', body: body);
      } else {
        await Api.i.put('/api/transactions/${widget.tx!.id}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final t = widget.tx;
    if (t == null) return;
    if (!await confirmDelete(context, 'Transakcja zostanie usunięta.')) return;
    try {
      await Api.i.delete('/api/transactions/${t.id}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {...txCategories, _category}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tx == null ? 'Nowa transakcja' : 'Edytuj transakcję',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (widget.tx != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Wydatek'), icon: Icon(Icons.remove)),
              ButtonSegment(value: 'income', label: Text('Przychód'), icon: Icon(Icons.add)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: widget.tx == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Kwota',
              suffixText: 'zł',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Kategoria', border: OutlineInputBorder()),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text('${categoryEmoji[c] ?? '✨'} $c')))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'inne'),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            leading: const Icon(Icons.event_outlined),
            title: Text(prettyDate(dateStr(_date))),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Opis (np. Biedronka, rachunek za prąd)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Paragon 🧾', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_pickedReceipt != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_pickedReceipt!, height: 200, fit: BoxFit.cover),
            )
          else if (_receiptFileId != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                Api.i.fileUrl(_receiptFileId!),
                headers: Api.i.imageHeaders,
                height: 200,
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
                    if (f != null) setState(() => _pickedReceipt = f);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_pickedReceipt == null && _receiptFileId == null
                      ? 'Dodaj zdjęcie paragonu'
                      : 'Zmień zdjęcie'),
                ),
              ),
              if (_pickedReceipt != null || _receiptFileId != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _pickedReceipt = null;
                    _receiptFileId = null;
                  }),
                  child: const Text('Usuń'),
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
                : const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}
