import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

final barItemsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  
  return client
      .from('bar_items_view')
      .stream(primaryKey: ['id'])
      .order('order_created_at')
      .map((data) => data.cast<Map<String, dynamic>>());
});

class BarDisplayScreen extends ConsumerWidget {
  const BarDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(barItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bar'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: itemsAsync.whenData((items) {
              final pending = items.where((i) => i['preparation_status'] == 'pending').length;
              final inProgress = items.where((i) => i['preparation_status'] == 'in_progress').length;
              
              return Row(
                children: [
                  if (pending > 0) ...[
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: Colors.red.shade700,
                        child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      label: const Text('Offen'),
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (inProgress > 0)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: Colors.blue.shade700,
                        child: Text('$inProgress', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      label: const Text('In Arbeit'),
                      backgroundColor: Colors.white,
                    ),
                ],
              );
            }).maybeWhen(
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_bar, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Keine offenen Bestellungen',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group items by table
          final groupedByTable = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final tableKey = item['table_number']?.toString() ?? 'Takeaway';
            groupedByTable.putIfAbsent(tableKey, () => []).add(item);
          }

          final sortedTables = groupedByTable.keys.toList()
            ..sort((a, b) {
              // Get earliest order time for each table
              final aTime = groupedByTable[a]!.first['order_created_at'] as String;
              final bTime = groupedByTable[b]!.first['order_created_at'] as String;
              return DateTime.parse(aTime).compareTo(DateTime.parse(bTime));
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTables.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final tableName = sortedTables[index];
              final tableItems = groupedByTable[tableName]!;
              
              return _BarOrderCard(
                tableName: tableName,
                items: tableItems,
                onStatusUpdate: (itemId, status) => _updateItemStatus(ref, itemId, status),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Fehler: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateItemStatus(WidgetRef ref, String itemId, String status) async {
    final repo = ref.read(ordersRepositoryProvider);
    try {
      await repo.updateItemPreparationStatus(itemId, status);
    } catch (e) {
      // Error handling - could show snackbar in production
      debugPrint('Error updating item status: $e');
    }
  }
}

class _BarOrderCard extends StatelessWidget {
  const _BarOrderCard({
    required this.tableName,
    required this.items,
    required this.onStatusUpdate,
  });

  final String tableName;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String itemId, String status) onStatusUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderTime = DateTime.parse(items.first['order_created_at'] as String);
    final elapsed = DateTime.now().difference(orderTime);
    
    // Determine card urgency color
    Color cardColor = theme.colorScheme.surface;
    Color borderColor = theme.colorScheme.outline.withOpacity(0.2);
    
    if (elapsed.inMinutes > 15) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade700;
    } else if (elapsed.inMinutes > 8) {
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade700;
    }

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_bar,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tisch $tableName',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${elapsed.inMinutes} Min. | ${_formatTime(orderTime)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Items
            ...items.map((item) => _BarItemRow(
                  item: item,
                  onStatusUpdate: onStatusUpdate,
                )),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _BarItemRow extends StatelessWidget {
  const _BarItemRow({
    required this.item,
    required this.onStatusUpdate,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(String itemId, String status) onStatusUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item['preparation_status'] as String;
    final quantity = item['quantity'] as int;
    final productName = item['product_name'] as String;
    final itemId = item['id'] as String;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'pending':
        statusColor = Colors.red.shade700;
        statusIcon = Icons.circle;
        statusLabel = 'Offen';
        break;
      case 'in_progress':
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.timelapse;
        statusLabel = 'In Arbeit';
        break;
      case 'ready':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        statusLabel = 'Fertig';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
        statusLabel = status;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${quantity}×',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      productName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Status buttons
              Row(
                children: [
                  if (status == 'pending')
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onStatusUpdate(itemId, 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Starten'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  if (status == 'in_progress') ...[
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => onStatusUpdate(itemId, 'pending'),
                        child: const Text('Zurück'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onStatusUpdate(itemId, 'ready'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Fertig'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                  if (status == 'ready')
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => onStatusUpdate(itemId, 'in_progress'),
                        child: const Text('Zurück'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
