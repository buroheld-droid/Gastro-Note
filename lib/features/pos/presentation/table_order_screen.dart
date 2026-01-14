import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product.dart';
import '../../products/providers/categories_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/providers/tables_provider.dart';
import '../../orders/domain/order_line.dart';
import '../../../core/providers/repository_providers.dart';

class TableOrderScreen extends ConsumerStatefulWidget {
  const TableOrderScreen({
    super.key,
    required this.table,
    this.existingOrderId,
  });

  final RestaurantTable table;
  final String? existingOrderId;

  @override
  ConsumerState<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends ConsumerState<TableOrderScreen> {
  String? _selectedCategoryId;
  final List<_OrderItem> _orderItems = [];

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final isAddToOrder = widget.existingOrderId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tisch ${widget.table.tableNumber}${isAddToOrder ? ' – Nachbestellen' : ''}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('${widget.table.capacity} Personen'),
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use vertical layout on phones, horizontal on tablets
          final isPhone = constraints.maxWidth < 768;
          
          if (isPhone) {
            // Phone: Vertical stacked layout
            return Column(
              children: [
                // Categories
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: categoriesAsync.when(
                    data: (categories) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          final isSelected = _selectedCategoryId == category.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(category.name),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategoryId = isSelected
                                      ? null
                                      : category.id;
                                });
                              },
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              selectedColor: Color(
                                int.parse(
                                  category.color?.replaceFirst('#', '0xFF') ??
                                      '0xFF22C55E',
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, _) =>
                        Text('Fehler beim Laden: $error'),
                  ),
                ),
                const Divider(height: 1),
                
                // Products (70% of remaining space)
                Expanded(
                  flex: 7,
                  child: _selectedCategoryId == null
                      ? const Center(child: Text('Wähle eine Kategorie'))
                      : _ProductsGrid(
                          categoryId: _selectedCategoryId!,
                          onProductTap: _addToOrder,
                        ),
                ),
                
                const Divider(height: 1),
                
                // Order summary (30% of remaining space)
                Expanded(
                  flex: 3,
                  child: _OrderPanel(
                    table: widget.table,
                    isAddToOrder: isAddToOrder,
                    orderItems: _orderItems,
                    onRemoveItem: (index) {
                      setState(() {
                        _orderItems.removeAt(index);
                      });
                    },
                    onSubmit: _submitOrder,
                  ),
                ),
              ],
            );
          } else {
            // Tablet/Desktop: Horizontal side-by-side layout
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: categoriesAsync.when(
                          data: (categories) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((category) {
                              final isSelected = _selectedCategoryId == category.id;
                              return FilterChip(
                                label: Text(category.name),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedCategoryId = isSelected
                                        ? null
                                        : category.id;
                                  });
                                },
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                selectedColor: Color(
                                  int.parse(
                                    category.color?.replaceFirst('#', '0xFF') ??
                                        '0xFF22C55E',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          loading: () => const CircularProgressIndicator(),
                          error: (error, _) =>
                              Text('Fehler beim Laden der Kategorien: $error'),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _selectedCategoryId == null
                            ? const Center(child: Text('Bitte wähle eine Kategorie'))
                            : _ProductsGrid(
                                categoryId: _selectedCategoryId!,
                                onProductTap: _addToOrder,
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _OrderPanel(
                    table: widget.table,
                    isAddToOrder: isAddToOrder,
                    orderItems: _orderItems,
                    onRemoveItem: (index) {
                      setState(() {
                        _orderItems.removeAt(index);
                      });
                    },
                    onSubmit: _submitOrder,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  void _addToOrder(Product product) {
    setState(() {
      final existingIndex = _orderItems.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0) {
        _orderItems[existingIndex] = _orderItems[existingIndex].copyWith(
          quantity: _orderItems[existingIndex].quantity + 1,
        );
      } else {
        _orderItems.add(_OrderItem(product: product, quantity: 1));
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_orderItems.isEmpty) return;
    final ordersRepo = ref.read(ordersRepositoryProvider);

    final lines = _orderItems
        .map(
          (e) => OrderLine(
            productId: e.product.id,
            productName: e.product.name,
            unitPrice: e.product.price,
            taxRate: e.product.taxRate,
            quantity: e.quantity,
          ),
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    // Schließ sofort - führe Save im Hintergrund aus (kein await!)
    if (mounted) {
      Navigator.of(context).pop(); // close progress dialog sofort
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingOrderId != null
                ? 'Speichere Positionen...'
                : 'Speichere Bestellung...',
          ),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
    
    // Starte Speicherung im Hintergrund (kein await - blockiert nicht!)
    try {
      if (widget.existingOrderId != null) {
        await ordersRepo.addItemsToOrder(
          orderId: widget.existingOrderId!,
          items: lines,
        );
      } else {
        await ordersRepo.createOrderForTable(
          tableId: widget.table.id,
          items: lines,
        );
      }

      // Invalidate tables cache im Hintergrund
      if (mounted) {
        ref.read(invalidateTablesProvider)();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }
}

class _ProductsGrid extends ConsumerWidget {
  const _ProductsGrid({required this.categoryId, required this.onProductTap});

  final String categoryId;
  final void Function(Product) onProductTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByCategoryProvider(categoryId));
    final theme = Theme.of(context);

    return productsAsync.when(
      data: (products) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            child: InkWell(
              onTap: () => onProductTap(product),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '€ ${product.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.table,
    required this.isAddToOrder,
    required this.orderItems,
    required this.onRemoveItem,
    required this.onSubmit,
  });

  final RestaurantTable table;
  final bool isAddToOrder;
  final List<_OrderItem> orderItems;
  final void Function(int) onRemoveItem;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = orderItems.fold<double>(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
    final tax = orderItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (item.product.price * item.quantity * (item.product.taxRate / 100)),
    );
    final total = subtotal + tax;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bon - Tisch ${table.tableNumber}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: orderItems.isEmpty
                  ? const Center(child: Text('Keine Artikel'))
                  : ListView.separated(
                      itemCount: orderItems.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = orderItems[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item.quantity}x ${item.product.name}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '€ ${(item.product.price * item.quantity).toStringAsFixed(2)}',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                                onPressed: () => onRemoveItem(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Zwischensumme', style: theme.textTheme.bodyLarge),
                Text(
                  '€ ${subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MwSt', style: theme.textTheme.bodyLarge),
                Text(
                  '€ ${tax.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: orderItems.isEmpty ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                '${isAddToOrder ? 'Hinzufügen' : 'Bestellen'} - € ${total.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem {
  final Product product;
  final int quantity;

  _OrderItem({required this.product, required this.quantity});

  _OrderItem copyWith({Product? product, int? quantity}) {
    return _OrderItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
