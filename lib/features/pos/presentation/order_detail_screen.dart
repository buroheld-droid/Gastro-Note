import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/pin_login_service.dart';
import '../../orders/data/orders_repository.dart';
import 'table_order_screen.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/providers/tables_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.table});
  final RestaurantTable table;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _payments = const [];
  bool _loading = true;
  String _method = 'cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _receivedCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _reload();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final repo = ref.read(ordersRepositoryProvider);
    try {
      final order = await repo.getOpenOrderForTable(widget.table.id);
      if (order != null) {
        final orderId = order['id'] as String;
        // Load items and payments in parallel
        final results = await Future.wait([
          repo.getOrderItems(orderId),
          repo.getPayments(orderId),
        ]);

        final items = (results[0] as List).cast<Map<String, dynamic>>();
        final pays = (results[1] as List).cast<Map<String, dynamic>>();

        if (mounted) {
          setState(() {
            _order = order;
            _items = items;
            _payments = pays;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  double get _subtotal => (_order?['subtotal'] as num?)?.toDouble() ?? 0.0;
  double get _tax => (_order?['tax_amount'] as num?)?.toDouble() ?? 0.0;
  double get _total => (_order?['total'] as num?)?.toDouble() ?? 0.0;
  double get _paid => _payments.fold<double>(
    0,
    (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0),
  );
  double get _due => (_total - _paid);

  Widget _buildStatusBadge(ThemeData theme, String status) {
    Color color;
    String label;

    switch (status) {
      case 'in_progress':
        color = Colors.orange;
        label = 'In Arbeit';
        break;
      case 'ready':
        color = Colors.green;
        label = 'Fertig';
        break;
      case 'delivered':
        color = Colors.blue;
        label = 'Serviert';
        break;
      default:
        color = Colors.red;
        label = 'Offen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Tisch ${widget.table.tableNumber} – Bestellung'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Keine Bestellung gefunden'))
              : ref.watch(tablesProvider).when(
                    data: (_) => _buildContent(context, theme),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Text('Fehler beim Laden der Tische: $error'),
                    ),
                  ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              // Items Section
              Padding(
                padding: EdgeInsets.all(isPhone ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Positionen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isPhone ? 8 : 12),
                    if (_items.isEmpty)
                      const Text('Keine Positionen')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final name = item['product_name'] as String;
                          final qty = item['quantity'] as int;
                          final price = (item['unit_price'] as num).toDouble();
                          final total = (item['total'] as num).toDouble();

                          final status =
                              (item['preparation_status'] as String?) ?? 'pending';

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isPhone ? 6 : 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$qty x $name',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '€ ${price.toStringAsFixed(2)} je',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStatusBadge(theme, status),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '€ ${total.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              // Summary Section
              Padding(
                padding: EdgeInsets.all(isPhone ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isPhone ? 8 : 12),
                    _SummaryRow(
                      label: 'Netto:',
                      value: '€ ${_subtotal.toStringAsFixed(2)}',
                      theme: theme,
                    ),
                    SizedBox(height: isPhone ? 4 : 6),
                    _SummaryRow(
                      label: 'MwSt:',
                      value: '€ ${_tax.toStringAsFixed(2)}',
                      theme: theme,
                    ),
                    SizedBox(height: isPhone ? 4 : 6),
                    _SummaryRow(
                      label: 'Gesamt:',
                      value: '€ ${_total.toStringAsFixed(2)}',
                      theme: theme,
                      isBold: true,
                    ),
                    SizedBox(height: isPhone ? 8 : 12),
                    _SummaryRow(
                      label: 'Bezahlt:',
                      value: '€ ${_paid.toStringAsFixed(2)}',
                      theme: theme,
                    ),
                    if (_due > 0.01)
                      Padding(
                        padding: EdgeInsets.only(top: isPhone ? 6 : 8),
                        child: _SummaryRow(
                          label: 'Noch zu zahlen:',
                          value: '€ ${_due.toStringAsFixed(2)}',
                          theme: theme,
                          valueColor: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              // Payments Section
              Padding(
                padding: EdgeInsets.all(isPhone ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zahlungen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isPhone ? 8 : 12),
                    if (_payments.isEmpty)
                      const Text('Keine Zahlungen')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          final method = payment['payment_method'] as String;
                          final amount =
                              (payment['amount'] as num).toDouble();

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: isPhone ? 6 : 8,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  method == 'cash' ? 'Bargeld' : 'Karte',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  '€ ${amount.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    SizedBox(height: isPhone ? 12 : 16),
                    // Payment Method & Amount Input
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: isPhone ? 12 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zahlung hinzufügen',
                            style: theme.textTheme.labelLarge,
                          ),
                          SizedBox(height: isPhone ? 8 : 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _method,
                                  isExpanded: true,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _method = value);
                                    }
                                  },
                                  items: [
                                    DropdownMenuItem(
                                      value: 'cash',
                                      child: Text(
                                        'Bargeld',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'card',
                                      child: Text(
                                        'Karte',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isPhone ? 8 : 12),
                          TextField(
                            controller: _amountCtrl,
                            decoration: InputDecoration(
                              labelText: 'Betrag (€)',
                              border: const OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isPhone ? 8 : 12,
                              ),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          if (_method == 'cash')
                            Padding(
                              padding: EdgeInsets.only(
                                top: isPhone ? 8 : 12,
                              ),
                              child: TextField(
                                controller: _receivedCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Erhalten (€)',
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: isPhone ? 8 : 12,
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                          if (_method == 'card')
                            Padding(
                              padding: EdgeInsets.only(
                                top: isPhone ? 8 : 12,
                              ),
                              child: TextField(
                                controller: _referenceCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Referenznummer (optional)',
                                  border: const OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: isPhone ? 8 : 12,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: isPhone ? 12 : 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _order == null
                                  ? null
                                  : _onAddPayment,
                              child: const Text('Zahlung hinzufügen'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Action Buttons
              Padding(
                padding: EdgeInsets.all(isPhone ? 12 : 16),
                child: isPhone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.tonal(
                            onPressed: _order == null ? null : _onAddItems,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            child: const Text('Positionen hinzufügen'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _items.isEmpty ? null : _showSplitDialog,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  child: const Text('Separieren'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _order == null ? null : _showCheckoutDialog,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.tertiary,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  child: const Text('Abkassieren'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: (_order != null && _due <= 0.01)
                                ? _onComplete
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            child: const Text('Abschließen'),
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonal(
                            onPressed: _order == null ? null : _onAddItems,
                            child: const Text('Positionen hinzufügen'),
                          ),
                          FilledButton.tonal(
                            onPressed: _items.isEmpty ? null : _showSplitDialog,
                            child: const Text('Separieren'),
                          ),
                          FilledButton(
                            onPressed: _order == null ? null : _showCheckoutDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.tertiary,
                            ),
                            child: const Text('Abkassieren'),
                          ),
                          FilledButton.tonal(
                            onPressed: (_order != null && _due <= 0.01)
                                ? _onComplete
                                : null,
                            child: const Text('Abschließen'),
                          ),
                        ],
                      ),
              ),
              SizedBox(height: isPhone ? 12 : 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onAddPayment() async {
    final repo = ref.read(ordersRepositoryProvider);
    final currentEmployee = ref.read(currentPinEmployeeProvider);
    final id = _order!['id'] as String;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte gültigen Betrag eingeben')),
        );
      }
      return;
    }

    if (currentEmployee == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mitarbeiter nicht authentifiziert')),
        );
      }
      return;
    }

    double? received;
    double? change;
    String? refStr;

    if (_method == 'cash') {
      received = double.tryParse(_receivedCtrl.text.trim());
      if (received != null && received >= amount) {
        change = received - amount;
      }
    } else if (_method == 'card') {
      refStr = _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim();
    }

    try {
      // Verwende addPaymentWithEmployee statt addPayment - Kellner wird erfasst
      await repo.addPaymentWithEmployee(
        orderId: id,
        method: _method,
        amount: amount,
        employeeId: currentEmployee.id,
        receivedAmount: received,
        changeAmount: change,
        reference: refStr,
      );

      _amountCtrl.clear();
      _receivedCtrl.clear();
      _referenceCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Zahlung gespeichert (${currentEmployee.name})',
            ),
          ),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _onAddItems() async {
    if (_order == null) return;
    final orderId = _order!['id'] as String;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TableOrderScreen(table: widget.table, existingOrderId: orderId),
      ),
    );

    if (!mounted) return;
    await _reload();
    ref.read(invalidateTablesProvider)();
  }

  void _showCheckoutDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: isPhone ? screenWidth * 0.9 : 400,
          child: Padding(
            padding: EdgeInsets.all(isPhone ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tisch Abkassieren',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: isPhone ? 12 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gesamtbetrag:'),
                    Text(
                      '€ ${_total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_due > 0.01)
                  Padding(
                    padding: EdgeInsets.only(top: isPhone ? 6 : 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Noch zu zahlen:'),
                        Text(
                          '€ ${_due.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: isPhone ? 16 : 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _onCheckout();
                      },
                      child: const Text('Abkassieren'),
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

  Future<void> _onCheckout() async {
    final repo = ref.read(ordersRepositoryProvider);
    final id = _order!['id'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Close dialog immediately
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tisch wird abgerechnet...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }

    // Run in background (fire-and-forget)
    _doCheckoutInBackground(repo, id);
  }

  Future<void> _doCheckoutInBackground(
    OrdersRepository repo,
    String id,
  ) async {
    try {
      if (_due > 0.01) {
        await repo.addPayment(
          orderId: id,
          method: 'cash',
          amount: _due,
        );
      }

      await repo.completeOrderAndFreeTable(id);

      if (mounted) {
        ref.read(invalidateTablesProvider)();
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _onComplete() async {
    final repo = ref.read(ordersRepositoryProvider);
    final id = _order!['id'] as String;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bestellung wird abgeschlossen...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }

    _doCompleteInBackground(repo, id);
  }

  Future<void> _doCompleteInBackground(
    OrdersRepository repo,
    String id,
  ) async {
    try {
      await repo.completeOrderAndFreeTable(id);

      if (mounted) {
        ref.read(invalidateTablesProvider)();
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _showSplitDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _SplitDialog(items: _items, onSplit: _onSplitConfirm),
    );
  }

  Future<void> _onSplitConfirm(
    Map<String, int> itemQuantities,
    String action,
    String? tableId,
  ) async {
    final repo = ref.read(ordersRepositoryProvider);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Positionen werden separiert...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }

    _doSplitInBackground(repo, itemQuantities, action, tableId);
  }

  Future<void> _doSplitInBackground(
    OrdersRepository repo,
    Map<String, int> itemQuantities,
    String action,
    String? tableId,
  ) async {
    try {
      final result = await repo
          .splitOrderItems(
            orderId: _order!['id'],
            itemQuantities: itemQuantities,
            action: action,
            targetTableId: tableId,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (action == 'checkout' && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _InvoicePaymentDialog(invoice: {'id': result}),
        );
      }

      if (mounted) {
        ref.read(invalidateTablesProvider)();
        _reload();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Zeitüberschreitung - Bitte überprüfe die Internetverbindung',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isBold
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                ),
        ),
      ],
    );
  }
}

class _SplitDialog extends ConsumerStatefulWidget {
  const _SplitDialog({required this.items, required this.onSplit});

  final List<Map<String, dynamic>> items;
  final Function(Map<String, int>, String, String?) onSplit;

  @override
  ConsumerState<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends ConsumerState<_SplitDialog> {
  late Map<String, int> _quantities;
  String _action = 'checkout';
  String? _targetTableId;

  @override
  void initState() {
    super.initState();
    _quantities = {
      for (final item in widget.items) item['id'] as String: 0
    };
  }

  int get _getTotalSelectedQty =>
      _quantities.values.fold(0, (sum, qty) => sum + qty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;
    final tablesAsync = ref.watch(tablesProvider);

    return Dialog(
      child: SizedBox(
        width: isPhone ? screenWidth * 0.9 : 500,
        child: Padding(
          padding: EdgeInsets.all(isPhone ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Positionen separieren',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: isPhone ? 12 : 16),
              Text(
                'Wähle Positionen zum Separieren:',
                style: theme.textTheme.labelLarge,
              ),
              SizedBox(height: isPhone ? 6 : 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.items.map((item) {
                      final id = item['id'] as String;
                      final maxQty = item['quantity'] as int;
                      final name = item['product_name'] as String;
                      final unitPrice =
                          (item['unit_price'] as num).toDouble();
                      final selectedQty = _quantities[id] ?? 0;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isPhone ? 6 : 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$maxQty x $name – € ${(maxQty * unitPrice).toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            SizedBox(height: isPhone ? 4 : 6),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  iconSize: 20,
                                  onPressed: selectedQty > 0
                                      ? () {
                                          setState(
                                            () =>
                                                _quantities[id] =
                                                    selectedQty - 1,
                                          );
                                        }
                                      : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    selectedQty.toString(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  iconSize: 20,
                                  onPressed: selectedQty < maxQty
                                      ? () {
                                          setState(
                                            () =>
                                                _quantities[id] =
                                                    selectedQty + 1,
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: isPhone ? 12 : 16),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: isPhone ? 8 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktion:',
                      style: theme.textTheme.labelLarge,
                    ),
                    SizedBox(height: isPhone ? 6 : 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(label: Text('Abkassieren'), value: 'checkout'),
                        ButtonSegment(label: Text('Tisch'), value: 'table'),
                      ],
                      selected: {_action},
                      onSelectionChanged: (value) {
                        setState(() => _action = value.first);
                      },
                    ),
                  ],
                ),
              ),
              if (_action == 'table') ...[
                SizedBox(height: isPhone ? 12 : 16),
                tablesAsync.when(
                  data: (tables) {
                    final availableTables = tables
                        .where((t) => t.status == 'available')
                        .toList();

                    if (availableTables.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Keine freien Tische verfügbar',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      );
                    }

                    return DropdownButton<String>(
                      hint: const Text('Zielttisch wählen'),
                      value: _targetTableId,
                      isExpanded: true,
                      onChanged: (tableId) {
                        setState(() => _targetTableId = tableId);
                      },
                      items: availableTables
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                'Tisch ${t.tableNumber} (${t.area})',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, st) => Text('Fehler: $err'),
                ),
              ],
              SizedBox(height: isPhone ? 16 : 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_getTotalSelectedQty == 0 ||
                            (_action == 'table' && _targetTableId == null))
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            final selectedQuantities =
                                Map<String, int>.fromEntries(
                              _quantities.entries
                                  .where((e) => e.value > 0),
                            );
                            widget.onSplit(
                              selectedQuantities,
                              _action,
                              _targetTableId,
                            );
                          },
                    child: const Text('Separieren'),
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

class _InvoicePaymentDialog extends ConsumerStatefulWidget {
  const _InvoicePaymentDialog({required this.invoice});

  final Map<String, dynamic> invoice;

  @override
  ConsumerState<_InvoicePaymentDialog> createState() =>
      _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState
    extends ConsumerState<_InvoicePaymentDialog> {
  String _method = 'cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _receivedCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;

    return Dialog(
      child: SizedBox(
        width: isPhone ? screenWidth * 0.9 : 400,
        child: Padding(
          padding: EdgeInsets.all(isPhone ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zahlung für Abrechnung',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: isPhone ? 12 : 16),
              Text(
                'Zahlungsmethode:',
                style: theme.textTheme.labelLarge,
              ),
              SizedBox(height: isPhone ? 6 : 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(label: Text('Bargeld'), value: 'cash'),
                  ButtonSegment(label: Text('Karte'), value: 'card'),
                ],
                selected: {_method},
                onSelectionChanged: (value) {
                  setState(() => _method = value.first);
                },
              ),
              SizedBox(height: isPhone ? 12 : 16),
              TextField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: 'Betrag (€)',
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isPhone ? 8 : 12,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (_method == 'cash')
                Padding(
                  padding: EdgeInsets.only(top: isPhone ? 8 : 12),
                  child: TextField(
                    controller: _receivedCtrl,
                    decoration: InputDecoration(
                      labelText: 'Erhalten (€)',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isPhone ? 8 : 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              if (_method == 'card')
                Padding(
                  padding: EdgeInsets.only(top: isPhone ? 8 : 12),
                  child: TextField(
                    controller: _referenceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Referenznummer (optional)',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isPhone ? 8 : 12,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: isPhone ? 16 : 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _savePayment,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Zahlung speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePayment() async {
    final repo = ref.read(ordersRepositoryProvider);
    final invoiceId = widget.invoice['id'] as String;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültigen Betrag eingeben')),
      );
      return;
    }

    double? received;
    double? change;
    String? refStr;

    if (_method == 'cash') {
      received = double.tryParse(_receivedCtrl.text.trim());
      if (received != null && received >= amount) {
        change = received - amount;
      }
    } else if (_method == 'card') {
      refStr = _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim();
    }

    setState(() => _loading = true);

    try {
      await repo.addPayment(
        orderId: invoiceId,
        method: _method,
        amount: amount,
        receivedAmount: received,
        changeAmount: change,
        reference: refStr,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahlung gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }
}
