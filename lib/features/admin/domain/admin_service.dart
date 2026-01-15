import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain Service für Admin-Funktionen (Gelöschte Bestellungen, etc.)
class AdminService {
  final _supabase = Supabase.instance.client;

  /// Stream von gelöschten Bestellungen heute (Real-time)
  Stream<List<Map<String, dynamic>>> getDeletedOrdersStream() {
    return _supabase
        .from('deleted_orders_view')
        .stream(primaryKey: ['id']).map((List<dynamic> data) {
      return List<Map<String, dynamic>>.from(
        data.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    });
  }

  /// Get einzelne gelöschte Bestellung mit Details
  Future<Map<String, dynamic>?> getDeletedOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('deleted_orders_view')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// RPC Call: Bestellung soft-delete mit Audit Trail
  /// Nur Manager/Admin können aufrufen
  Future<Map<String, dynamic>> deleteOrderWithAudit({
    required String orderId,
    required String deletedByEmployeeId,
    required String deletionReason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'delete_order_with_audit',
        params: {
          'p_order_id': orderId,
          'p_deleted_by_id': deletedByEmployeeId,
          'p_deletion_reason': deletionReason,
        },
      );

      if (response == null) {
        throw Exception('RPC returned null');
      }

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      rethrow;
    }
  }

  /// RPC Call: Gelöschte Bestellung wiederherstellen
  /// Nur Manager/Admin können aufrufen
  Future<Map<String, dynamic>> restoreDeletedOrder({
    required String orderId,
    required String restoredByEmployeeId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'restore_deleted_order',
        params: {
          'p_order_id': orderId,
          'p_restored_by_id': restoredByEmployeeId,
        },
      );

      if (response == null) {
        throw Exception('RPC returned null');
      }

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      rethrow;
    }
  }

  /// Get Audit Trail für eine Bestellung (alle Änderungen)
  Future<List<Map<String, dynamic>>> getOrderAuditTrail(
      String orderId) async {
    try {
      // Note: Benötigt eine audit_log Tabelle in Zukunft
      // Für jetzt: Lese deletion Info aus deleted_orders_view
      final response = await _supabase
          .from('deleted_orders_view')
          .select()
          .eq('id', orderId);

      return List<Map<String, dynamic>>.from(
        response.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    } catch (e) {
      rethrow;
    }
  }
}
