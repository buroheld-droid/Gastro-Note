import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
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

  Future<void> _load() async {
    setState(() => _loading = true);
    await _reload();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final repo = ref.read(ordersRepositoryProvider);

    try {
      Map<String, dynamic>? order;
      if (widget.table.currentOrderId != null) {
        order = await repo.getOpenOrderForTable(widget.table.id);
      } else {
        order = await repo.getOpenOrderForTable(widget.table.id);
      }

      if (order != null) {
        final orderId = order['id'] as String;
        // Paralleles Laden von Items und Payments
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Tisch ${widget.table.tableNumber} – Bestellung'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_order == null)
          ? const Center(child: Text('Keine offene Bestellung'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 768;
                
                if (isPhone) {
                  // Phone: Vertical stacked layout
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Items section
                          Text('Positionen', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton.tonal(
                                onPressed: _order == null ? null : _onAddItems,
                                child: const Text('Nachbestellen'),
                              ),
                              const SizedBox(width: 8),
                              if (_items.isNotEmpty)
                                FilledButton.tonal(
                                  onPressed: _items.isEmpty ? null : _showSplitDialog,
                                  child: const Text('Separieren'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final it = _items[i];
                                final qty = it['quantity'] as int? ?? 0;
                                final name = it['product_name'] as String? ?? '';
                                final total =
                                    (it['total'] as num?)?.toDouble() ?? 0.0;
                                return ListTile(
                                  dense: true,
                                  title: Text('$qty x $name'),
                                  trailing: Text('€ ${total.toStringAsFixed(2)}'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Totals section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Zwischensumme'),
                                      Text('€ ${_subtotal.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('MwSt'),
                                      Text('€ ${_tax.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Gesamt', style: theme.textTheme.titleMedium),
                                      Text(
                                        '€ ${_total.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Payments section
                          Text('Zahlungen', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  ..._payments.map(
                                    (p) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('${p['payment_method']}'),
                                      trailing: Text(
                                        '€ ${(p['amount'] as num).toStringAsFixed(2)}',
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Bezahlt'),
                                      Text('€ ${_paid.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Offen'),
                                      Text(
                                        '€ ${_due.clamp(0, double.infinity).toStringAsFixed(2)}',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: _due > 0
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment method selection
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'cash', label: Text('Bar')),
                              ButtonSegment(value: 'card', label: Text('Karte')),
                            ],
                            selected: {_method},
                            onSelectionChanged: (s) =>
                                setState(() => _method = s.first),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Betrag (EUR)',
                            ),
                          ),
                          if (_method == 'cash')
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _receivedCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Erhalten (EUR) – optional',
                                ),
                              ),
                            ),
                          if (_method == 'card')
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _referenceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Referenz – optional',
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          
                          // Action buttons
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _order == null ? null : _onAddPayment,
                              child: const Text('Zahlung hinzufügen'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _order == null ? null : _showCheckoutDialog,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.tertiary,
                              ),
                              child: const Text('Tisch Abkassieren'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: (_order != null && _due <= 0.01)
                                  ? _onComplete
                                  : null,
                              child: const Text('Bestellung abschließen'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Tablet/Desktop: Horizontal side-by-side layout
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Positionen', style: theme.textTheme.titleLarge),
                                  Row(
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: _order == null ? null : _onAddItems,
                                        child: const Text('Nachbestellen'),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_items.isNotEmpty)
                                        FilledButton.tonal(
                                          onPressed: _items.isEmpty ? null : _showSplitDialog,
                                          child: const Text('Separieren'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _items.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final it = _items[i];
                                    final qty = it['quantity'] as int? ?? 0;
                                    final name = it['product_name'] as String? ?? '';
                                    final total = (it['total'] as num?)?.toDouble() ?? 0.0;
                                    return ListTile(
                                      dense: true,
                                      title: Text('$qty x $name'),
                                      trailing: Text('€ ${total.toStringAsFixed(2)}'),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Zwischensumme'),
                                  Text('€ ${_subtotal.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('MwSt'),
                                  Text('€ ${_tax.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Gesamt', style: theme.textTheme.titleMedium),
                                  Text(
                                    '€ ${_total.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Zahlungen', style: theme.textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _payments.length,
                                  itemBuilder: (context, i) {
                                    final p = _payments[i];
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('${p['payment_method']}'),
                                      trailing: Text(
                                        '€ ${(p['amount'] as num).toStringAsFixed(2)}',
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Bezahlt'),
                                  Text('€ ${_paid.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Offen'),
                                  Text(
                                    '€ ${_due.clamp(0, double.infinity).toStringAsFixed(2)}',
                                    style: _due > 0
                                        ? theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'cash', label: Text('Bar')),
                                  ButtonSegment(value: 'card', label: Text('Karte')),
                                ],
                                selected: {_method},
                                onSelectionChanged: (s) => setState(() => _method = s.first),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Betrag (EUR)',
                                ),
                              ),
                              if (_method == 'cash')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextField(
                                    controller: _receivedCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Erhalten (EUR) – optional',
                                    ),
                                  ),
                                ),
                              if (_method == 'card')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextField(
                                    controller: _referenceCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Referenz – optional',
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _order == null ? null : _onAddPayment,
                                  child: const Text('Zahlung hinzufügen'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _order == null ? null : _showCheckoutDialog,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.tertiary,
                                  ),
                                  child: const Text('Tisch Abkassieren'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: (_order != null && _due <= 0.01) ? _onComplete : null,
                                  child: const Text('Bestellung abschließen'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            );
        }
      },
    );

  Future<void> _onAddPayment() async {
    final repo = ref.read(ordersRepositoryProvider);
    final id = _order!['id'] as String;
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
      if (received != null) {
        change = (received - amount);
        if (change < 0) change = 0;
      }
    } else if (_method == 'card') {
      refStr = _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim();
    }

    await repo.addPayment(
      orderId: id,
      method: _method,
      amount: amount,
      receivedAmount: received,
      changeAmount: change,
      reference: refStr,
    );
    await _reloadPayments();
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
    await ref.read(tablesProvider.future);
  }

  Future<void> _reloadPayments() async {
    final repo = ref.read(ordersRepositoryProvider);
    final id = _order!['id'] as String;
    final pays = await repo.getPayments(id);
    setState(() => _payments = pays);
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tisch Abkassieren',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Noch zu zahlen:'),
                        Text(
                          '€ ${_due.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
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

    // Schließ sofort - zeige Message
    if (mounted) {
      Navigator.of(context).pop(); // close loading dialog SOFORT
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tisch wird abgerechnet...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
    
    // Starte Speicherung im ECHTEN Hintergrund (kein await!)
    _doCheckoutInBackground(repo, id);
  }

  Future<void> _doCheckoutInBackground(OrdersRepository repo, String id) async {
    try {
      // Erfasse Zahlung für den ausstehenden Betrag
      if (_due > 0.01) {
        await repo.addPayment(orderId: id, method: 'cash', amount: _due);
      }

      // Schließe Bestellung ab und gebe Tisch frei
      await repo.completeOrderAndFreeTable(id);
      
      // Invalidiere und reload im Hintergrund (blockiert nicht mehr!)
      if (mounted) {
        ref.read(invalidateTablesProvider)();
        // Nicht auf reload warten - nur starten
        _reloadPayments();
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
    
    // Zeige Message sofort
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bestellung wird abgeschlossen...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
    
    // Starte im echten Hintergrund (kein await!)
    _doCompleteInBackground(repo, id);
  }

  Future<void> _doCompleteInBackground(OrdersRepository repo, String id) async {
    try {
      await repo.completeOrderAndFreeTable(id);
      
      // Invalidiere und reload im Hintergrund
      if (mounted) {
        ref.read(invalidateTablesProvider)();
        // Nicht auf reload warten - nur starten
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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Schließ sofort - zeige Message
    if (mounted) {
      Navigator.of(context).pop(); // close progress dialog SOFORT
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Positionen werden separiert...'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
    
    // Starte im echten Hintergrund (kein await!)
    _doSplitInBackground(repo, itemQuantities, action, tableId);
  }

  Future<void> _doSplitInBackground(
    OrdersRepository repo,
    Map<String, int> itemQuantities,
    String action,
    String? tableId,
  ) async {
    dynamic result;
    try {
      result = await repo
          .splitOrderItems(
            orderId: _order!['id'],
            itemQuantities: itemQuantities,
            action: action,
            targetTableId: tableId,
          )
          .timeout(const Duration(seconds: 10));
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
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
      return;
    }
    if (!mounted) return;

    // Bei "checkout" → Zahlungs-Dialog anzeigen
    if (action == 'checkout' && mounted) {
      final invoice = {'id': result};
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _InvoicePaymentDialog(invoice: invoice),
      );
    }

    // Invalidiere Tische im Hintergrund (KEIN await!)
    if (mounted) {
      ref.read(invalidateTablesProvider)();
      // Nicht auf reload warten - nur starten
      _reload();
    }
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
  late Map<String, int> _quantities; // id -> qty to split
  String _action = 'checkout'; // 'checkout' or 'table'
  String? _targetTableId;

  @override
  void initState() {
    super.initState();
    // Initialize quantities to 0 for all items
    _quantities = {for (var item in widget.items) (item['id'] as String): 0};
  }

  int _getTotalSelectedQty() {
    return _quantities.values.fold(0, (sum, qty) => sum + qty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSelected = _getTotalSelectedQty();
    final tablesAsync = ref.watch(tablesProvider);

    return Dialog(
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Positionen separieren', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                'Wähle Positionen zum Separieren:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.items.map((item) {
                      final id = item['id'] as String;
                      final maxQty = item['quantity'] as int;
                      final name = item['product_name'] as String;
                      final unitPrice = (item['unit_price'] as num).toDouble();
                      final selectedQty = _quantities[id] ?? 0;
                      final selectedTotal = selectedQty * unitPrice;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$maxQty x $name – € ${(maxQty * unitPrice).toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: selectedQty > 0
                                      ? () {
                                          setState(() {
                                            _quantities[id] = selectedQty - 1;
                                          });
                                        }
                                      : null,
                                  iconSize: 20,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    '$selectedQty',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: selectedQty < maxQty
                                      ? () {
                                          setState(() {
                                            _quantities[id] = selectedQty + 1;
                                          });
                                        }
                                      : null,
                                  iconSize: 20,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 12),
                                if (selectedQty > 0)
                                  Text(
                                    '→ € ${selectedTotal.toStringAsFixed(2)}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
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
              const SizedBox(height: 16),
              Text('Aktion:', style: theme.textTheme.labelLarge),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'checkout', label: Text('Abkassieren')),
                  ButtonSegment(value: 'table', label: Text('Auf Tisch')),
                ],
                selected: {_action},
                onSelectionChanged: (s) {
                  setState(() {
                    _action = s.first;
                    _targetTableId = null;
                  });
                },
              ),
              if (_action == 'table') ...[
                const SizedBox(height: 12),
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
                              child: Text('Tisch ${t.tableNumber} (${t.area})'),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, st) => Text('Fehler: $err'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        (totalSelected == 0 ||
                            (_action == 'table' && _targetTableId == null))
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            final selectedQuantities =
                                Map<String, int>.fromEntries(
                                  _quantities.entries.where((e) => e.value > 0),
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

class _InvoicePaymentDialogState extends ConsumerState<_InvoicePaymentDialog> {
  String _method = 'cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingInvoice = true;
  Map<String, dynamic>? _fullInvoice;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    // If invoice already has 'total', it's complete
    if (widget.invoice.containsKey('total')) {
      setState(() {
        _fullInvoice = widget.invoice;
        _loadingInvoice = false;
      });
      final total = (widget.invoice['total'] as num).toDouble();
      _amountCtrl.text = total.toStringAsFixed(2);
      return;
    }

    // Otherwise, fetch from DB
    final invoiceId = widget.invoice['id'] as String;
    try {
      final repo = ref.read(ordersRepositoryProvider);
      final response = await repo.getInvoiceById(invoiceId);

      if (mounted) {
        setState(() {
          _fullInvoice = response;
          _loadingInvoice = false;
        });
        final total = (response['total'] as num).toDouble();
        _amountCtrl.text = total.toStringAsFixed(2);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingInvoice = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Rechnung: $e')),
        );
      }
    }
  }

  double get _invoiceTotal =>
      (_fullInvoice?['total'] as num?)?.toDouble() ?? 0.0;
  String get _invoiceNumber =>
      (_fullInvoice?['invoice_number'] as String?) ?? 'N/A';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingInvoice) {
      return const Dialog(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Dialog(
      child: SizedBox(
        width: 450,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rechnung $_invoiceNumber',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Summe:'),
                  Text(
                    '€ ${_invoiceTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Zahlungsart:', style: theme.textTheme.labelLarge),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Bar')),
                  ButtonSegment(value: 'card', label: Text('Karte')),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Betrag (EUR)'),
                enabled: false,
              ),
              if (_method == 'cash')
                TextField(
                  controller: _receivedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Erhalten (EUR) – optional',
                  ),
                ),
              if (_method == 'card')
                TextField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Referenz – optional',
                  ),
                ),
              const SizedBox(height: 16),
              if (_method == 'cash' && _receivedCtrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Wechselgeld:'),
                      Text(
                        '€ ${((double.tryParse(_receivedCtrl.text) ?? 0) - _invoiceTotal).clamp(0, double.infinity).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _onPaymentComplete,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Zahlung abschließen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPaymentComplete() async {
    final repo = ref.read(ordersRepositoryProvider);
    final invoiceId = widget.invoice['id'] as String;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ungültiger Betrag')));
      return;
    }

    setState(() => _loading = true);

    try {
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

      // Paralleles Ausführen: Payment + Invoice Completion
      await Future.wait([
        repo.addPaymentToInvoice(
          invoiceId: invoiceId,
          method: _method,
          amount: amount,
          receivedAmount: received,
          changeAmount: change,
          reference: refStr,
        ),
        repo.completeInvoice(invoiceId),
      ]);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teilrechnung $_invoiceNumber bezahlt')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
