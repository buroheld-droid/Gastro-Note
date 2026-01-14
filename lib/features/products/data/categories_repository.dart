import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/category.dart';

class CategoriesRepository {
  final SupabaseClient _client;

  CategoriesRepository(this._client);

  Future<List<Category>> getAll({bool activeOnly = true}) async {
  final response = activeOnly
    ? await _client
      .from('categories')
      .select()
      .eq('is_active', true)
      .isFilter('deleted_at', null)
      .order('sort_order')
    : await _client
      .from('categories')
      .select()
      .order('sort_order');

    return (response as List).map((json) => Category.fromJson(json)).toList();
  }

  Future<Category> getById(String id) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('id', id)
        .single();

    return Category.fromJson(response);
  }

  Future<Category> create(Category category) async {
    final response = await _client
        .from('categories')
        .insert(category.toJson())
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<Category> update(Category category) async {
    final response = await _client
        .from('categories')
        .update(category.toJson())
        .eq('id', category.id)
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<void> delete(String id) async {
    await _client
        .from('categories')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
