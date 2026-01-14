import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gastro_note/features/orders/data/orders_repository.dart';
import 'package:gastro_note/features/orders/domain/order_line.dart';

// Diese Tests fokussieren sich auf die Eingabevalidierung der Repository-Methoden,
// damit keine komplexen Supabase-Mock-Ketten nötig sind.
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('OrdersRepository Validation', () {
    late OrdersRepository ordersRepository;

    setUp(() {
      ordersRepository = OrdersRepository(MockSupabaseClient());
    });

    test('createOrderForTable wirft bei leeren Items', () {
      expect(
        () => ordersRepository.createOrderForTable(
          tableId: 'table-123',
          items: const [],
        ),
        throwsArgumentError,
      );
    });

    test('addItemsToOrder wirft bei leeren Items', () {
      expect(
        () => ordersRepository.addItemsToOrder(
          orderId: 'order-123',
          items: const [],
        ),
        throwsArgumentError,
      );
    });

    test('splitOrderItems wirft bei leerer Map', () {
      expect(
        () => ordersRepository.splitOrderItems(
          orderId: 'order-123',
          itemQuantities: const {},
          action: 'checkout',
        ),
        throwsArgumentError,
      );
    });

    test('splitOrderItems wirft bei Action=table ohne targetTableId', () {
      expect(
        () => ordersRepository.splitOrderItems(
          orderId: 'order-123',
          itemQuantities: const {'item-1': 1},
          action: 'table',
        ),
        throwsArgumentError,
      );
    });

    test('OrderLine berechnet lineSubtotal korrekt', () {
      final line = OrderLine(
        productId: 'prod-1',
        productName: 'Test',
        quantity: 2,
        unitPrice: 5.0,
        taxRate: 10,
      );

      expect(line.lineSubtotal, 10.0);
      expect(line.lineTax, 1.0);
      expect(line.lineTotal, 11.0);
    });
  });
}
