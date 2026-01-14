import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/domain/order_line.dart';

class OrdersRepository {
  final SupabaseClient _client;
  OrdersRepository(this._client);

  Future<String> createOrderForTable({
    required String tableId,
    required List<OrderLine> items,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Mindestens eine Position ist erforderlich');
    }

    final subtotal = items.fold<double>(0, (s, i) => s + i.lineSubtotal);
    final tax = items.fold<double>(0, (s, i) => s + i.lineTax);
    final total = subtotal + tax;

    final orderNumber = _generateOrderNumber();

    final orderInsert = await _client
        .from('orders')
        .insert({
          'order_number': orderNumber,
          'table_id': tableId,
          'subtotal': subtotal.toStringAsFixed(2),
          'tax_amount': tax.toStringAsFixed(2),
          'discount_amount': '0.00',
          'total': total.toStringAsFixed(2),
          'status': 'open',
          'notes': notes,
        })
        .select('id')
        .single();

    final orderId = orderInsert['id'] as String;

    final itemsPayload = items
        .map(
          (i) => {
            'order_id': orderId,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice.toStringAsFixed(2),
            'tax_rate': i.taxRate,
            'subtotal': i.lineSubtotal.toStringAsFixed(2),
            'tax_amount': i.lineTax.toStringAsFixed(2),
            'total': i.lineTotal.toStringAsFixed(2),
            'modifiers': '[]',
          },
        )
        .toList();

    await _client.from('order_items').insert(itemsPayload);

    // Tisch belegen und current_order_id setzen
    await _client
        .from('tables')
        .update({'status': 'occupied', 'current_order_id': orderId})
        .eq('id', tableId);

    return orderId;
  }

  Future<void> addItemsToOrder({
    required String orderId,
    required List<OrderLine> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Mindestens eine Position ist erforderlich');
    }

    // Insert new items
    final itemsPayload = items
        .map(
          (i) => {
            'order_id': orderId,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice.toStringAsFixed(2),
            'tax_rate': i.taxRate,
            'subtotal': i.lineSubtotal.toStringAsFixed(2),
            'tax_amount': i.lineTax.toStringAsFixed(2),
            'total': i.lineTotal.toStringAsFixed(2),
            'modifiers': '[]',
          },
        )
        .toList();

    await _client.from('order_items').insert(itemsPayload);

    // Ensure totals and table status stay in sync
    await _recalculateOrderTotals(orderId);

    final order = await _client
        .from('orders')
        .select('table_id')
        .eq('id', orderId)
        .maybeSingle();

    final tableId = order?['table_id'] as String?;
    if (tableId != null) {
      await _client
          .from('tables')
          .update({'status': 'occupied', 'current_order_id': orderId})
          .eq('id', tableId);
    }
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    return 'O${now.year}${_pad2(now.month)}${_pad2(now.day)}-${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}';
  }

  String _pad2(int v) => v.toString().padLeft(2, '0');

  Future<Map<String, dynamic>?> getOpenOrderForTable(String tableId) async {
    final res = await _client
        .from('orders')
        .select()
        .eq('table_id', tableId)
        .eq('status', 'open')
        .order('created_at')
        .limit(1);
    final list = res as List;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final res = await _client
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPayments(String orderId) async {
    final res = await _client
        .from('payments')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> addPayment({
    required String orderId,
    required String method, // cash, card, other
    required double amount,
    double? receivedAmount,
    double? changeAmount,
    String? reference,
    String? notes,
  }) async {
    await _client.from('payments').insert({
      'order_id': orderId,
      'payment_method': method,
      'amount': amount.toStringAsFixed(2),
      'received_amount': receivedAmount?.toStringAsFixed(2),
      'change_amount': changeAmount?.toStringAsFixed(2),
      'reference': reference,
      'notes': notes,
    });
  }

  Future<void> completeOrderAndFreeTable(String orderId) async {
    // Get table_id from order
    final order = await _client
        .from('orders')
        .select('id, table_id')
        .eq('id', orderId)
        .single();
    final tableId = order['table_id'] as String?;

    await _client
        .from('orders')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);

    if (tableId != null) {
      await _client
          .from('tables')
          .update({'status': 'available', 'current_order_id': null})
          .eq('id', tableId);
    }
  }

  /// Split order items: either to a new invoice (checkout) or to another table
  /// [itemIds] = list of order_item IDs to split
  /// [action] = 'checkout' | 'table'
  /// [targetTableId] = table ID if action=='table', else null
  Future<String> splitOrderItems({
    required String orderId,
    required Map<String, int> itemQuantities, // id -> qty to split
    required String action, // 'checkout' or 'table'
    String? targetTableId, // for 'table' action
  }) async {
    if (itemQuantities.isEmpty)
      throw ArgumentError('Keine Positionen ausgewählt');
    if (action == 'table' && (targetTableId?.isEmpty ?? true)) {
      throw ArgumentError('Zielttisch erforderlich');
    }

    // Fetch the items
    final itemIds = itemQuantities.keys.toList();
    final objectIds = itemIds.map((id) => id as Object).toList();
    final itemRes = await _client
        .from('order_items')
        .select()
        .inFilter('id', objectIds);
    final items = itemRes as List;

    double subtotal = 0;
    double taxAmount = 0;

    // Calculate totals based on split quantities
    for (final item in items) {
      final itemId = item['id'] as String;
      final splitQty = itemQuantities[itemId] ?? 0;
      final unitPrice = (item['unit_price'] as num).toDouble();
      final taxRate = (item['tax_rate'] as num).toDouble();

      final itemSubtotal = unitPrice * splitQty;
      final itemTax = itemSubtotal * (taxRate / 100);

      subtotal += itemSubtotal;
      taxAmount += itemTax;
    }
    final total = subtotal + taxAmount;

    if (action == 'checkout') {
      // Create a new invoice for immediate checkout
      final invoiceNumber = _generateInvoiceNumber();
      final invoiceInsert = await _client
          .from('invoices')
          .insert({
            'order_id': orderId,
            'invoice_number': invoiceNumber,
            'subtotal': subtotal.toStringAsFixed(2),
            'tax_amount': taxAmount.toStringAsFixed(2),
            'total': total.toStringAsFixed(2),
            'status': 'open',
          })
          .select('id')
          .single();
      final invoiceId = invoiceInsert['id'] as String;

      // Link items to invoice with split quantities
      final invoiceItemsPayload = items.map((item) {
        final itemId = item['id'] as String;
        final splitQty = itemQuantities[itemId] ?? 0;
        final unitPrice = (item['unit_price'] as num).toDouble();
        final taxRate = (item['tax_rate'] as num).toDouble();

        final itemSubtotal = unitPrice * splitQty;
        final itemTax = itemSubtotal * (taxRate / 100);
        final itemTotal = itemSubtotal + itemTax;

        return {
          'invoice_id': invoiceId,
          'order_item_id': item['id'],
          'quantity': splitQty,
          'unit_price': unitPrice.toStringAsFixed(2),
          'tax_rate': taxRate,
          'subtotal': itemSubtotal.toStringAsFixed(2),
          'tax_amount': itemTax.toStringAsFixed(2),
          'total': itemTotal.toStringAsFixed(2),
        };
      }).toList();
      await _client.from('invoice_items').insert(invoiceItemsPayload);

      // Update original order items: reduce quantities
      for (final item in items) {
        final itemId = item['id'] as String;
        final originalQty = item['quantity'] as int;
        final splitQty = itemQuantities[itemId] ?? 0;
        final remainingQty = originalQty - splitQty;

        if (remainingQty <= 0) {
          // Delete item completely if all moved
          await _client.from('order_items').delete().eq('id', itemId);
        } else {
          // Update quantity and recalculate totals
          final unitPrice = (item['unit_price'] as num).toDouble();
          final taxRate = (item['tax_rate'] as num).toDouble();

          final newSubtotal = unitPrice * remainingQty;
          final newTax = newSubtotal * (taxRate / 100);
          final newTotal = newSubtotal + newTax;

          await _client
              .from('order_items')
              .update({
                'quantity': remainingQty,
                'subtotal': newSubtotal.toStringAsFixed(2),
                'tax_amount': newTax.toStringAsFixed(2),
                'total': newTotal.toStringAsFixed(2),
              })
              .eq('id', itemId);
        }
      }

      // Recalculate order totals
      await _recalculateOrderTotals(orderId);

      return invoiceId;
    } else if (action == 'table') {
      // Create a new order on target table with split items
      final newOrderNumber = _generateOrderNumber();
      final newOrderInsert = await _client
          .from('orders')
          .insert({
            'order_number': newOrderNumber,
            'table_id': targetTableId,
            'subtotal': subtotal.toStringAsFixed(2),
            'tax_amount': taxAmount.toStringAsFixed(2),
            'total': total.toStringAsFixed(2),
            'status': 'open',
          })
          .select('id')
          .single();
      final newOrderId = newOrderInsert['id'] as String;

      // Create new items with split quantities
      final newItemsPayload = items.map((item) {
        final itemId = item['id'] as String;
        final splitQty = itemQuantities[itemId] ?? 0;
        final unitPrice = (item['unit_price'] as num).toDouble();
        final taxRate = (item['tax_rate'] as num).toDouble();

        final itemSubtotal = unitPrice * splitQty;
        final itemTax = itemSubtotal * (taxRate / 100);
        final itemTotal = itemSubtotal + itemTax;

        return {
          'order_id': newOrderId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': splitQty,
          'unit_price': unitPrice.toStringAsFixed(2),
          'tax_rate': taxRate,
          'subtotal': itemSubtotal.toStringAsFixed(2),
          'tax_amount': itemTax.toStringAsFixed(2),
          'total': itemTotal.toStringAsFixed(2),
          'modifiers': item['modifiers'],
        };
      }).toList();
      await _client.from('order_items').insert(newItemsPayload);

      // Update original order items: reduce quantities
      for (final item in items) {
        final itemId = item['id'] as String;
        final originalQty = item['quantity'] as int;
        final splitQty = itemQuantities[itemId] ?? 0;
        final remainingQty = originalQty - splitQty;

        if (remainingQty <= 0) {
          await _client.from('order_items').delete().eq('id', itemId);
        } else {
          final unitPrice = (item['unit_price'] as num).toDouble();
          final taxRate = (item['tax_rate'] as num).toDouble();

          final newSubtotal = unitPrice * remainingQty;
          final newTax = newSubtotal * (taxRate / 100);
          final newTotal = newSubtotal + newTax;

          await _client
              .from('order_items')
              .update({
                'quantity': remainingQty,
                'subtotal': newSubtotal.toStringAsFixed(2),
                'tax_amount': newTax.toStringAsFixed(2),
                'total': newTotal.toStringAsFixed(2),
              })
              .eq('id', itemId);
        }
      }

      // Recalculate both orders
      await _recalculateOrderTotals(orderId);

      // Update target table to occupied
      if (targetTableId != null) {
        await _client
            .from('tables')
            .update({'status': 'occupied', 'current_order_id': newOrderId})
            .eq('id', targetTableId);
      }

      return newOrderId;
    }
    throw ArgumentError('Ungültige Action');
  }

  Future<void> _recalculateOrderTotals(String orderId) async {
    final items = await getOrderItems(orderId);

    // Wenn keine Items mehr da sind, Tisch freigeben und Bestellung als completed markieren
    if (items.isEmpty) {
      final order = await _client
          .from('orders')
          .select('table_id')
          .eq('id', orderId)
          .maybeSingle();

      final tableId = order?['table_id'] as String?;

      await _client
          .from('orders')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'subtotal': '0.00',
            'tax_amount': '0.00',
            'total': '0.00',
          })
          .eq('id', orderId);

      if (tableId != null) {
        await _client
            .from('tables')
            .update({'status': 'available', 'current_order_id': null})
            .eq('id', tableId);
      }
      return;
    }

    double subtotal = 0;
    double taxAmount = 0;

    for (final item in items) {
      subtotal += (item['subtotal'] as num).toDouble();
      taxAmount += (item['tax_amount'] as num).toDouble();
    }

    final total = subtotal + taxAmount;

    await _client
        .from('orders')
        .update({
          'subtotal': subtotal.toStringAsFixed(2),
          'tax_amount': taxAmount.toStringAsFixed(2),
          'total': total.toStringAsFixed(2),
        })
        .eq('id', orderId);
  }

  Future<List<Map<String, dynamic>>> getInvoices(String orderId) async {
    final res = await _client
        .from('invoices')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getInvoiceById(String invoiceId) async {
    final res = await _client
        .from('invoices')
        .select()
        .eq('id', invoiceId)
        .single();
    return res;
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(String invoiceId) async {
    final res = await _client
        .from('invoice_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> completeInvoice(String invoiceId) async {
    await _client
        .from('invoices')
        .update({'status': 'completed'})
        .eq('id', invoiceId);
  }

  Future<void> addPaymentToInvoice({
    required String invoiceId,
    required String method, // cash, card, other
    required double amount,
    double? receivedAmount,
    double? changeAmount,
    String? reference,
    String? notes,
  }) async {
    await _client.from('payments').insert({
      'invoice_id': invoiceId,
      'payment_method': method,
      'amount': amount.toStringAsFixed(2),
      'received_amount': receivedAmount?.toStringAsFixed(2),
      'change_amount': changeAmount?.toStringAsFixed(2),
      'reference': reference,
      'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(
    String invoiceId,
  ) async {
    final res = await _client
        .from('payments')
        .select()
        .eq('invoice_id', invoiceId)
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    return 'INV${now.year}${_pad2(now.month)}${_pad2(now.day)}-${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}';
  }

  // Kitchen & Admin Methods (RLS-aware)
  Future<List<Map<String, dynamic>>> getKitchenOrders(
    String restaurantId,
  ) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(id, product_id, quantity, notes, status)')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'in_progress')
        .or('status.eq.pending')
        .order('created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _client
        .from('orders')
        .update({'status': newStatus})
        .eq('id', orderId);
  }

  Future<Map<String, dynamic>> getTodayRevenueSummary(
    String restaurantId,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final res = await _client
        .from('orders')
        .select('total')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay.toIso8601String())
        .lte('created_at', today.toIso8601String());

    final orders = (res as List).cast<Map<String, dynamic>>();
    final total = orders.fold<double>(
      0,
      (sum, o) => sum + (double.tryParse(o['total'].toString()) ?? 0),
    );

    return {
      'total': total,
      'count': orders.length,
      'average': orders.isEmpty ? 0 : total / orders.length,
    };
  }

  Future<List<Map<String, dynamic>>> getEmployeeRevenueSummary(
    String restaurantId,
  ) async {
    final res = await _client.rpc(
      'get_employee_revenue_summary',
      params: {'p_restaurant_id': restaurantId},
    );
    return (res as List).cast<Map<String, dynamic>>();
  }

  // Kitchen Display System Methods
  Future<void> updateItemPreparationStatus(
    String itemId,
    String status,
  ) async {
    await _client.from('order_items').update({
      'preparation_status': status,
      'prepared_at': status == 'ready' ? DateTime.now().toIso8601String() : null,
    }).eq('id', itemId);
  }

  Future<List<Map<String, dynamic>>> getKitchenItems() async {
    final res = await _client
        .from('kitchen_items_view')
        .select()
        .order('order_created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getBarItems() async {
    final res = await _client
        .from('bar_items_view')
        .select()
        .order('order_created_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // Revenue & Analytics Methods
  Future<Map<String, dynamic>> getTodayRevenueSummary() async {
    final res = await _client
        .from('daily_revenue_summary_view')
        .select()
        .single();
    return res as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getEmployeeRevenueToday() async {
    final res = await _client
        .from('daily_employee_revenue_view')
        .select()
        .order('total_revenue', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getHourlyRevenue() async {
    final res = await _client
        .from('hourly_revenue_view')
        .select()
        .order('hour', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Markiere Order als abgeschlossen durch Mitarbeiter
  Future<void> completeOrder(String orderId, String completedByEmployeeId) async {
    await _client
        .from('orders')
        .update({
          'status': 'completed',
          'completed_by': completedByEmployeeId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  /// Speichere Zahlung mit Mitarbeiter-ID
  Future<void> addPaymentWithEmployee({
    required String orderId,
    required String method,
    required double amount,
    required String employeeId,
    double? receivedAmount,
    double? changeAmount,
    String? reference,
  }) async {
    await _client.from('payments').insert({
      'order_id': orderId,
      'payment_method': method,
      'amount': amount.toStringAsFixed(2),
      'received_amount': receivedAmount?.toStringAsFixed(2),
      'change_amount': changeAmount?.toStringAsFixed(2),
      'reference': reference,
      'created_by': employeeId,
    });
  }
}
