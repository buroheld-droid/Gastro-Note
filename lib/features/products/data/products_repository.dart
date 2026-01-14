import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/product.dart';

class ProductsRepository {
  final SupabaseClient _client;

  ProductsRepository(this._client);

  Future<List<Product>> getAll({bool activeOnly = true}) async {
    final response = activeOnly
        ? await _client
              .from('products')
              .select()
              .eq('is_active', true)
              .isFilter('deleted_at', null)
              .order('sort_order')
        : await _client.from('products').select().order('sort_order');

    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> getByCategory(String categoryId) async {
    final response = await _client
        .from('products')
        .select()
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .order('sort_order');

    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> getById(String id) async {
    final response = await _client
        .from('products')
        .select()
        .eq('id', id)
        .single();

    return Product.fromJson(response);
  }

  Future<Product> create(Product product) async {
    final response = await _client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<Product> update(Product product) async {
    final response = await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id)
        .select()
        .single();

    return Product.fromJson(response);
  }

  Future<void> delete(String id) async {
    await _client
        .from('products')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  // Einfaches Create: minimale Felder, DB generiert ID/Timestamps
  Future<Product> createSimple({
    required String name,
    String? categoryId,
    required double price,
    required double taxRate,
    String unit = 'Stück',
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final response = await _client
        .from('products')
        .insert({
          'name': name,
          'category_id': categoryId,
          'price': price,
          'tax_rate': taxRate,
          'unit': unit,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return Product.fromJson(response);
  }

  // Einfaches Update: nur relevante Felder
  Future<void> updateSimple({
    required String id,
    required String name,
    String? categoryId,
    required double price,
    required double taxRate,
    String unit = 'Stück',
    bool isActive = true,
  }) async {
    await _client
        .from('products')
        .update({
          'name': name,
          'category_id': categoryId,
          'price': price,
          'tax_rate': taxRate,
          'unit': unit,
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
