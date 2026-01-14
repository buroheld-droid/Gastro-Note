import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/restaurant_table.dart';

class TablesRepository {
  final SupabaseClient _client;

  TablesRepository(this._client);

  Future<List<RestaurantTable>> getAll() async {
    final response = await _client
        .from('tables')
        .select()
        .order('table_number');
    return (response as List).map((json) => RestaurantTable.fromJson(json)).toList();
  }

  Future<List<RestaurantTable>> getByArea(String area) async {
    final response = await _client
        .from('tables')
        .select()
        .eq('area', area)
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .order('sort_order');

    return (response as List).map((json) => RestaurantTable.fromJson(json)).toList();
  }

  Future<RestaurantTable> getById(String id) async {
    final response = await _client
        .from('tables')
        .select()
        .eq('id', id)
        .single();

    return RestaurantTable.fromJson(response);
  }

  Future<RestaurantTable> create(RestaurantTable table) async {
    final response = await _client
        .from('tables')
        .insert(table.toJson())
        .select()
        .single();

    return RestaurantTable.fromJson(response);
  }

  Future<RestaurantTable> update(RestaurantTable table) async {
    final response = await _client
        .from('tables')
        .update(table.toJson())
        .eq('id', table.id)
        .select()
        .single();

    return RestaurantTable.fromJson(response);
  }

  Future<void> updateStatus(String id, String status) async {
    await _client
        .from('tables')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<RestaurantTable?> getByTableNumber(String tableNumber) async {
    try {
      final response = await _client
          .from('tables')
          .select()
          .eq('table_number', tableNumber)
          .single();
      return RestaurantTable.fromJson(response);
    } catch (e) {
      return null; // Tisch nicht gefunden
    }
  }

  Future<void> delete(String id) async {
    await _client
        .from('tables')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
