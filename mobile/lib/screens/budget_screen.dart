import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'photo_view_screen.dart';
import 'transaction_edit_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  BudgetSummary? _summary;
  List<Tx> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = monthStr(_month);
      final results = await Future.wait([
        Api.i.get('/api/budget/summary', query: {'month': m}),
        Api.i.get('/api/transactions', query: {'month': m}),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = BudgetSummary.fromJson(results[0] as Map<String, dynamic>);
        _txs = (results[1] as List).map((e) => Tx.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Future<void> _editLimit(String category, int currentLimit) async {
    final controller = TextEditingController(
        text: currentLimit > 0 ? (currentLimit / 100).toStringAsFixed(2).replaceAll('.', ',') : '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Limit: ${categoryEmoji[category] ?? '✨'} $category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Limit miesięczny (zł)',
            hintText: '0 = usuń limit',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
        ],
      ),
    );
    if (saved != true) return;
    final grosze = parseMoney(controller.text) ?? 0;
    try {
      await Api.i.put('/api/budget/limits', body: {
        'month': monthStr(_month),
        'category': category,
        'limitGrosze': grosze,
      });
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addLimit() async {
    final existing = _summary?.categories.map((c) => c.category).toSet() ?? {};
    final available = txCategories.where((c) => !existing.contains(c)).toList();
    if (available.isEmpty) return;
    final category = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Limit dla kategorii'),
        children: available
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text('${categoryEmoji[c] ?? '✨'} $c'),
                ))
            .toList(),
      ),
    );
    if (category != null) await _editLimit(category, 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final scheme = Theme.of(context).colorScheme;
    final balance = (s?.incomeGrosze ?? 0) - (s?.expenseGrosze ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budżet domowy 💰', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'budget-fab',
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const TransactionEditScreen()),
          );
          if (changed == true) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
              Text(
                DateFormat('LLLL yyyy', 'pl').format(_month),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftMonth(1)),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Przychody', style: TextStyle(fontSize: 12)),
                                    Text(formatMoney(s?.incomeGrosze ?? 0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, color: Colors.green)),
                                    const SizedBox(height: 8),
                                    const Text('Wydatki', style: TextStyle(fontSize: 12)),
                                    Text(formatMoney(s?.expenseGrosze ?? 0),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700, color: scheme.error)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Bilans', style: TextStyle(fontSize: 12)),
                                    Text(
                                      formatMoney(balance),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: balance >= 0 ? Colors.green : scheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SectionHeader(
                          '📊 Kategorie i limity',
                          trailing: TextButton.icon(
                            onPressed: _addLimit,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Limit'),
                          ),
                        ),
                        if (s == null || s.categories.isEmpty)
                          const Card(
                              child: EmptyState(
                                  emoji: '🧮', text: 'Dodaj wydatki albo ustaw limity,\nżeby coś tu zobaczyć')),
                        ...?s?.categories.map((c) {
                          final overBudget = c.limitGrosze > 0 && c.spentGrosze > c.limitGrosze;
                          return Card(
                            child: ListTile(
                              leading: Text(categoryEmoji[c.category] ?? '✨',
                                  style: const TextStyle(fontSize: 24)),
                              title: Text(c.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: c.limitGrosze > 0
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (c.spentGrosze / c.limitGrosze).clamp(0.0, 1.0),
                                          minHeight: 6,
                                          color: overBudget ? scheme.error : scheme.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatMoney(c.spentGrosze),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: overBudget ? scheme.error : null)),
                                  if (c.limitGrosze > 0)
                                    Text('z ${formatMoney(c.limitGrosze)}',
                                        style: TextStyle(fontSize: 11, color: scheme.outline)),
                                ],
                              ),
                              onTap: () => _editLimit(c.category, c.limitGrosze),
                            ),
                          );
                        }),
                        const SectionHeader('🧾 Transakcje'),
                        if (_txs.isEmpty)
                          const Card(
                              child: EmptyState(
                                  emoji: '🛍️', text: 'Brak transakcji w tym miesiącu.\nDodaj plusem!')),
                        ..._txs.map((t) => Card(
                              child: ListTile(
                                leading: Text(
                                  t.kind == 'income' ? '💵' : (categoryEmoji[t.category] ?? '✨'),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                title: Text(t.description.isEmpty ? t.category : t.description),
                                subtitle: Text('${prettyDate(t.occurredOn)} · ${t.category}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (t.receiptFileId != null)
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long_outlined),
                                        tooltip: 'Zobacz paragon',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PhotoViewScreen(fileId: t.receiptFileId!),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '${t.kind == 'income' ? '+' : '-'}${formatMoney(t.amountGrosze)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: t.kind == 'income' ? Colors.green : scheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => TransactionEditScreen(tx: t)),
                                  );
                                  if (changed == true) _load();
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
