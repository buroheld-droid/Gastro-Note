import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/category.dart';
import '../providers/products_provider.dart';

class BulkUpdateDialog extends ConsumerStatefulWidget {
  const BulkUpdateDialog({super.key, required this.category});
  final Category category;

  @override
  ConsumerState<BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends ConsumerState<BulkUpdateDialog> {
  String _mode = 'price'; // price or tax
  final _valueCtrl = TextEditingController(text: '10');
  bool _inProgress = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Massenänderungen – ${widget.category.name}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'price', label: Text('Preis +%')),
                  ButtonSegment(value: 'tax', label: Text('MwSt setzen')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _mode == 'price' ? 'Prozent (+/-)' : 'MwSt (%)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _inProgress
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _inProgress ? null : _apply,
                    child: _inProgress
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Anwenden'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _apply() async {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen gültigen Wert eingeben')),
      );
      return;
    }
    setState(() => _inProgress = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final products = await repo.getByCategory(widget.category.id);
      if (_mode == 'price') {
        final factor = 1 + (value / 100.0);
        for (final p in products) {
          await repo.updateSimple(
            id: p.id,
            name: p.name,
            categoryId: p.categoryId,
            price: double.parse((p.price * factor).toStringAsFixed(2)),
            taxRate: p.taxRate,
            unit: p.unit,
            isActive: p.isActive,
          );
        }
      } else {
        for (final p in products) {
          await repo.updateSimple(
            id: p.id,
            name: p.name,
            categoryId: p.categoryId,
            price: p.price,
            taxRate: value,
            unit: p.unit,
            isActive: p.isActive,
          );
        }
      }
      if (mounted) {
        ref.read(invalidateProductsProvider)();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Massenänderungen angewendet')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

class CSVImportDialog extends ConsumerStatefulWidget {
  const CSVImportDialog({super.key});
  @override
  ConsumerState<CSVImportDialog> createState() => _CSVImportDialogState();
}

class _CSVImportDialogState extends ConsumerState<CSVImportDialog> {
  final _csvCtrl = TextEditingController(
    text:
        'name,category,price,tax,active\nPizza Margherita,Pizzen,7.50,7,true\nCola 0,33l,Getränke,2.50,19,true',
  );
  bool _createMissingCategories = true;
  bool _inProgress = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CSV Import – Produkte', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Spalten: name,category,price,tax,[unit],[active]\nEinheit leer => Stück · Active leer => true · Trennung: Komma oder Semikolon',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _csvCtrl,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _createMissingCategories,
                onChanged: (v) => setState(() => _createMissingCategories = v),
                title: const Text('Fehlende Kategorien automatisch anlegen'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _inProgress
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _inProgress ? null : _import,
                    child: _inProgress
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Importieren'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _inProgress = true);
    try {
      final prodRepo = ref.read(productsRepositoryProvider);
      final catRepo = ref.read(categoriesRepositoryProvider);
      final cats = await catRepo.getAll();
      final Map<String, Category> byName = {
        for (final c in cats) c.name.toLowerCase(): c,
      };

      final lines = _csvCtrl.text.trim().split('\n');
      if (lines.isEmpty) throw Exception('Keine CSV-Daten');
      final startIdx = lines.first.toLowerCase().contains('name') ? 1 : 0;
      int createdCount = 0;
      for (int i = startIdx; i < lines.length; i++) {
        final row = _parseCsvLine(lines[i]);
        if (row.length < 5) continue;
        final name = row[0];
        final catName = row[1];
        final price = double.tryParse(row[2]) ?? 0;
        final tax = double.tryParse(row[3]) ?? 0;
        final unit =
            row.length >= 6 && row[4].isNotEmpty ? row[4] : 'Stück';
        final activeIdx = row.length >= 6 ? 5 : 4;
        final activeVal = row[activeIdx].toLowerCase();
        final active = activeVal.isEmpty || activeVal == 'true';

        String? categoryId = byName[catName.toLowerCase()]?.id;
        if (categoryId == null &&
            _createMissingCategories &&
            catName.isNotEmpty) {
          final createdCat = await catRepo.create(
            Category(
              id: 'temp',
              name: catName,
              description: null,
              color: '#22C55E',
              sortOrder: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deletedAt: null,
            ),
          );
          byName[catName.toLowerCase()] = createdCat;
          categoryId = createdCat.id;
        }

        if (name.isEmpty || price <= 0) continue;
        await prodRepo.createSimple(
          name: name,
          categoryId: categoryId,
          price: price,
          taxRate: tax,
          unit: unit,
          isActive: active,
          sortOrder: 0,
        );
        createdCount++;
      }

      if (mounted) {
        ref.read(invalidateProductsProvider)();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$createdCount Produkte importiert')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  List<String> _parseCsvLine(String line) {
    if (line.contains(';')) {
      return line.split(';').map((s) => s.trim()).toList();
    }
    return line.split(',').map((s) => s.trim()).toList();
  }
}
