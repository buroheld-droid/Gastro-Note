import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/providers/categories_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import '_bulk_csv_dialogs.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final search = _searchCtrl.text.trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produkte', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Suchen oder filtern...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _onCreateCategory,
                child: const Text('Neue Kategorie'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _onImportCsv,
                child: const Text('CSV Import'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _onCreateProduct,
                icon: const Icon(Icons.add),
                label: const Text('Neues Produkt'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: search.isNotEmpty
                ? _SearchResults(query: search)
                : categoriesAsync.when(
                    data: (categories) => _CategoryList(categories: categories),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Fehler: $e')),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateProduct() async {
    final created = await showDialog<Product?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(),
    );
    if (created != null && mounted) {
      // Cache invalidieren
      ref.read(invalidateProductsProvider)();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt "${created.name}" erstellt')),
      );
    }
  }

  Future<void> _onCreateCategory() async {
    final created = await showDialog<Category?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CategoryFormDialog(),
    );
    if (created != null && mounted) {
      ref.read(invalidateCategoriesProvider)();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategorie "${created.name}" erstellt')),
      );
    }
  }

  Future<void> _onImportCsv() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CSVImportDialog(),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final productsAsync = ref.watch(productsByCategoryProvider(cat.id));
        final color = Color(
          int.parse(cat.color?.replaceFirst('#', '0xFF') ?? '0xFF22C55E'),
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Text(cat.name, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Kategorie bearbeiten',
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final updated = await showDialog<Category?>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => _CategoryFormDialog(category: cat),
                        );
                        if (updated != null) {
                          ref.read(invalidateCategoriesProvider)();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Kategorie "${updated.name}" aktualisiert',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Kategorie löschen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Kategorie löschen?'),
                            content: Text(
                              '"${cat.name}" wird ausgeblendet (Soft-Delete).',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final repo = ref.read(categoriesRepositoryProvider);
                          await repo.delete(cat.id);
                          ref.read(invalidateCategoriesProvider)();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kategorie gelöscht')),
                          );
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'bulk') {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => BulkUpdateDialog(category: cat),
                          );
                          ref.read(invalidateProductsProvider)();
                        } else if (val == 'new-product') {
                          final created = await showDialog<Product?>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                _ProductFormDialog(presetCategoryId: cat.id),
                          );
                          if (created != null) {
                            ref.read(invalidateProductsProvider)();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Produkt "${created.name}" erstellt',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'bulk',
                          child: Text('Massenänderungen'),
                        ),
                        PopupMenuItem(
                          value: 'new-product',
                          child: Text('Neues Produkt in Kategorie'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                productsAsync.when(
                  data: (products) => Column(
                    children: products
                        .map((p) => _ProductTile(product: p))
                        .toList(),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text('Fehler beim Laden: $e'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      data: (products) {
        final filtered = products
            .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('Keine Treffer'));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ProductTile(product: filtered[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(product.name),
      subtitle: Text(
        'Preis: € ${product.price.toStringAsFixed(2)} · MwSt: ${product.taxRate.toStringAsFixed(0)}%',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await showDialog<Product?>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _ProductFormDialog(product: product),
              );
              if (updated != null) {
                ref.read(invalidateProductsProvider)();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Produkt "${updated.name}" aktualisiert'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Produkt löschen?'),
                  content: Text(
                    '"${product.name}" wird ausgeblendet (Soft-Delete).',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Löschen'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final repo = ref.read(productsRepositoryProvider);
                await repo.delete(product.id);
                ref.read(invalidateProductsProvider)();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Produkt gelöscht')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends ConsumerStatefulWidget {
  const _ProductFormDialog({this.product, this.presetCategoryId});
  final Product? product;
  final String? presetCategoryId;

  @override
  ConsumerState<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({this.category});
  final Category? category;

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#22C55E');
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _colorCtrl.text = c.color ?? '#22C55E';
      _active = c.isActive;
    }
  }

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
                widget.category == null
                    ? 'Neue Kategorie'
                    : 'Kategorie bearbeiten',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Farbe (Hex, z.B. #22C55E)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Aktiv'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final color = _colorCtrl.text.trim().isEmpty
        ? null
        : _colorCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte Namen angeben')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(categoriesRepositoryProvider);
      if (widget.category == null) {
        final created = await repo.create(
          Category(
            id: 'temp', // DB vergibt ID
            name: name,
            description: null,
            color: color,
            sortOrder: 0,
            isActive: _active,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deletedAt: null,
          ),
        );
        if (mounted) Navigator.of(context).pop(created);
      } else {
        final c = widget.category!;
        final updated = await repo.update(
          Category(
            id: c.id,
            name: name,
            description: c.description,
            color: color,
            sortOrder: c.sortOrder,
            isActive: _active,
            createdAt: c.createdAt,
            updatedAt: DateTime.now(),
            deletedAt: c.deletedAt,
          ),
        );
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

class _ProductFormDialogState extends ConsumerState<_ProductFormDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '19');
  String? _categoryId;
  String _unit = 'Stück';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toStringAsFixed(2);
      _taxCtrl.text = p.taxRate.toStringAsFixed(0);
      _categoryId = p.categoryId;
      _unit = p.unit;
      _active = p.isActive;
    }
    _categoryId ??= widget.presetCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    return Dialog(
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product == null ? 'Neues Produkt' : 'Produkt bearbeiten',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (cats) => DropdownButtonFormField<String>(
                  value: _categoryId,
                  isExpanded: true,
                  items: cats
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _categoryId = val),
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Fehler: $e'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Preis (EUR)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _taxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'MwSt (%)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Aktiv'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final tax = double.tryParse(_taxCtrl.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Name und gültigen Preis angeben')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      Product result;
      if (widget.product == null) {
        result = await repo.createSimple(
          name: name,
          categoryId: _categoryId,
          price: price,
          taxRate: tax,
          unit: _unit,
          isActive: _active,
          sortOrder: 0,
        );
      } else {
        await repo.updateSimple(
          id: widget.product!.id,
          name: name,
          categoryId: _categoryId,
          price: price,
          taxRate: tax,
          unit: _unit,
          isActive: _active,
        );
        result = await repo.getById(widget.product!.id);
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
