import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../employees/domain/employee.dart';
import '../../pos/services/pin_login_service.dart';
import '../providers/admin_providers.dart';

/// Admin-Screen für gelöschte Bestellungen Management
/// Nur Manager/Admin können gelöschte Bestellungen einsehen und ggf. wiederherstellen
class DeletedOrdersAdminScreen extends ConsumerStatefulWidget {
  const DeletedOrdersAdminScreen({super.key});

  @override
  ConsumerState<DeletedOrdersAdminScreen> createState() =>
      _DeletedOrdersAdminScreenState();
}

class _DeletedOrdersAdminScreenState
    extends ConsumerState<DeletedOrdersAdminScreen> {
  String _selectedPaymentMethod = 'all'; // all, cash, card
  DateTime? _selectedDate;
  final _reasonSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEmployee = ref.watch(currentPinEmployeeProvider);
    final deletedOrdersAsync = ref.watch(deletedOrdersProvider);

    // Sicherheitscheck: Nur Manager/Admin
    if (currentEmployee == null ||
        (currentEmployee.role != 'Manager' && currentEmployee.role != 'Inhaber')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gelöschte Bestellungen')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'Nur Manager/Admin dürfen\ngelöschte Bestellungen sehen',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelöschte Bestellungen'),
        elevation: 0,
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Admin: ${currentEmployee.firstName}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Datum Filter
                  Tooltip(
                    message: 'Wähle Datum',
                    child: InputChip(
                      label: Text(
                        _selectedDate == null
                            ? 'Alle Daten'
                            : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                      ),
                      onPressed: () => _selectDate(context),
                      onDeleted: _selectedDate != null
                          ? () => setState(() => _selectedDate = null)
                          : null,
                      avatar: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Payment Method Filter
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('Alle'),
                      ),
                      ButtonSegment(
                        value: 'cash',
                        label: Text('Bar'),
                      ),
                      ButtonSegment(
                        value: 'card',
                        label: Text('Karte'),
                      ),
                    ],
                    selected: {_selectedPaymentMethod},
                    onSelectionChanged: (value) {
                      setState(() => _selectedPaymentMethod = value.first);
                    },
                  ),
                  const SizedBox(width: 12),

                  // Search/Filter Icon
                  Tooltip(
                    message: 'Nach Grund suchen',
                    child: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _showReasonFilterDialog(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Content
          Expanded(
            child: deletedOrdersAsync.when(
              data: (deletedOrders) {
                // Filter
                var filtered = deletedOrders.where((order) {
                  // Date filter
                  if (_selectedDate != null) {
                    final orderDate = (order['deletion_timestamp'] as DateTime).toLocal();
                    if (orderDate.year != _selectedDate!.year ||
                        orderDate.month != _selectedDate!.month ||
                        orderDate.day != _selectedDate!.day) {
                      return false;
                    }
                  }

                  // Payment method filter
                  if (_selectedPaymentMethod != 'all') {
                    if (order['payment_method'] != _selectedPaymentMethod) {
                      return false;
                    }
                  }

                  // Reason search filter
                  if (_reasonSearchCtrl.text.isNotEmpty) {
                    final reason =
                        (order['deletion_reason'] as String?)?? '';
                    if (!reason
                        .toLowerCase()
                        .contains(_reasonSearchCtrl.text.toLowerCase())) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'Keine gelöschten Bestellungen gefunden',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _DeletedOrderCard(order: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text('Fehler: $e'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _showReasonFilterDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nach Grund suchen'),
        content: TextField(
          controller: _reasonSearchCtrl,
          decoration: InputDecoration(
            hintText: 'z.B. "Doppel-Eintrag"',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }
}

/// Card für einzelne gelöschte Bestellung
class _DeletedOrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;

  const _DeletedOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentEmployee = ref.watch(currentPinEmployeeProvider);

    final orderNumber = order['order_number'] as String?? 'N/A';
    final tableNumber = order['table_number'] as String?? 'N/A';
    final orderTotal = order['order_total'] as double?? 0.0;
    final paymentMethod = order['payment_method'] as String?? '';
    final waiterName = order['waiter_name'] as String?? 'Unknown';
    final deletedByName = order['deleted_by_name'] as String?? 'Unknown';
    final deletionReason = order['deletion_reason'] as String?? 'N/A';
    final deletionTimestamp = order['deletion_timestamp'] as DateTime?;
    final productNames = order['product_names'] as String?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showOrderDetails(context, order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.left(
              color: Colors.red.shade600,
              width: 4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order Number + Total + Status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Bestellung #$orderNumber',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Tisch $tableNumber'),
                                backgroundColor: Colors.grey.shade200,
                                labelStyle:
                                    theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 16, color: theme.disabledColor),
                              const SizedBox(width: 4),
                              Text(
                                'Kellner: $waiterName',
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Total Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '€${orderTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            paymentMethod == 'cash' ? 'Bar' : 'Karte',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Deletion Info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_outline,
                              size: 18, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Gelöscht von ${deletedByName}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (deletionTimestamp != null)
                        Text(
                          'am ${DateFormat('dd.MM.yyyy HH:mm:ss').format(deletionTimestamp.toLocal())}',
                          style: theme.textTheme.labelSmall,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.comment_outlined,
                              size: 16, color: Colors.orange.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Grund: $deletionReason',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Products Info
                if (productNames.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produkte:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productNames,
                        style: theme.textTheme.labelSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetails(context, order),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Details'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _onRestoreOrder(context, ref, order),
                        icon: const Icon(Icons.restore),
                        label: const Text('Wiederherstellen'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bestellung #${order['order_number']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Tisch:', order['table_number'] ?? 'N/A'),
              _DetailRow(
                'Kellner:',
                order['waiter_name'] ?? 'Unknown',
              ),
              _DetailRow('Zahlungsmethode:', order['payment_method'] ?? ''),
              _DetailRow(
                'Gesamtbetrag:',
                '€${(order['order_total'] as double?? 0).toStringAsFixed(2)}',
              ),
              _DetailRow(
                'Netto:',
                '€${(order['order_net'] as double?? 0).toStringAsFixed(2)}',
              ),
              _DetailRow(
                'MwSt (19%):',
                '€${(order['order_tax'] as double?? 0).toStringAsFixed(2)}',
              ),
              const Divider(),
              _DetailRow(
                'Gelöscht von:',
                order['deleted_by_name'] ?? 'Unknown',
                isWarning: true,
              ),
              _DetailRow(
                'Zeitstempel:',
                order['deletion_timestamp'] != null
                    ? DateFormat('dd.MM.yyyy HH:mm:ss')
                        .format((order['deletion_timestamp'] as DateTime).toLocal())
                    : 'N/A',
                isWarning: true,
              ),
              _DetailRow(
                'Grund:',
                order['deletion_reason'] ?? 'N/A',
                isWarning: true,
              ),
              const SizedBox(height: 12),
              if (order['product_names'] != null && (order['product_names'] as String).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produkte:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order['product_names'] as String,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _onRestoreOrder(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bestellung wiederherstellen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bestellung #${order['order_number']} wird wiederhergestellt.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'Die Bestellung wird wieder als "active" markiert und in der normalen Übersicht sichtbar.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(ordersRepositoryProvider);
      final currentEmployee = ref.read(currentPinEmployeeProvider);

      if (currentEmployee == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentifizierung erforderlich')),
          );
        }
        return;
      }

      final orderId = order['id'] as String;
      await repo.restoreDeletedOrder(orderId: orderId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bestellung #${order['order_number']} wiederhergestellt',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

      // Invalidate Provider
      ref.refresh(deletedOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Helper Widget für Detail-Zeilen
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _DetailRow(
    this.label,
    this.value, {
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orange.shade700 : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isWarning ? Colors.orange.shade700 : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
