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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final isAddToOrder = widget.existingOrderId != null;

    return Scaffold(
      key: _scaffoldKey,
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
      endDrawer: _selectedCategoryId != null
          ? Drawer(
              width: MediaQuery.of(context).size.width * 0.75,
              child: _ProductsDrawer(
                categoryId: _selectedCategoryId!,
                onProductTap: (product) {
                  _addToOrder(product);
                  // Drawer bleibt offen - Benutzer schließt ihn manuell
                },
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use vertical layout on phones, horizontal on tablets
          final isPhone = constraints.maxWidth < 768;
          
          if (isPhone) {
            // Phone: New layout with order in center, products as drawer
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
                                if (_selectedCategoryId != null) {
                                  // Open drawer when category selected
                                  _scaffoldKey.currentState?.openEndDrawer();
                                }
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
                
                // Order items in the center - main focus
                Expanded(
                  child: _orderItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Noch keine Artikel',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Wähle eine Kategorie und füge Artikel hinzu',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orderItems.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _orderItems[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Quantity badge
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${item.quantity}×',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Product info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '€ ${item.product.price.toStringAsFixed(2)} pro Stück',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Total and remove button
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '€ ${(item.product.price * item.quantity).toStringAsFixed(2)}',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: theme.colorScheme.error,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _orderItems.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Bottom summary and order button
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gesamt',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '€ ${_calculateTotal().toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _orderItems.isEmpty ? null : _submitOrder,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            isAddToOrder ? 'Hinzufügen' : 'Bestellen',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
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

  double _calculateTotal() {
    final subtotal = _orderItems.fold<double>(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
    final tax = _orderItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (item.product.price * item.quantity * (item.product.taxRate / 100)),
    );
    return subtotal + tax;
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

class _ProductsDrawer extends ConsumerWidget {
  const _ProductsDrawer({
    required this.categoryId,
    required this.onProductTap,
  });

  final String categoryId;
  final void Function(Product) onProductTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByCategoryProvider(categoryId));
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Drawer header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Speisekarte',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Products list
          Expanded(
            child: productsAsync.when(
              data: (products) => ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    child: InkWell(
                      onTap: () => onProductTap(product),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (product.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      product.description!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '€ ${product.price.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
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
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fehler: $error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;
    
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
      margin: EdgeInsets.all(isPhone ? 8 : 16),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bon - Tisch ${table.tableNumber}',
              style: isPhone ? theme.textTheme.titleMedium : theme.textTheme.titleLarge,
            ),
            SizedBox(height: isPhone ? 8 : 12),
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
            Divider(height: isPhone ? 16 : 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Zwischensumme',
                  style: isPhone ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge,
                ),
                Text(
                  '€ ${subtotal.toStringAsFixed(2)}',
                  style: isPhone ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge,
                ),
              ],
            ),
            SizedBox(height: isPhone ? 4 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MwSt',
                  style: isPhone ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge,
                ),
                Text(
                  '€ ${tax.toStringAsFixed(2)}',
                  style: isPhone ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge,
                ),
              ],
            ),
            SizedBox(height: isPhone ? 8 : 12),
            FilledButton(
              onPressed: orderItems.isEmpty ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(isPhone ? 44 : 48),
              ),
              child: Text(
                '${isAddToOrder ? 'Hinzufügen' : 'Bestellen'} - € ${total.toStringAsFixed(2)}',
                style: isPhone ? const TextStyle(fontSize: 14) : null,
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
