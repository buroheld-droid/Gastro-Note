import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/products/data/categories_repository.dart';
import '../../features/products/data/products_repository.dart';
import '../../features/tables/data/tables_repository.dart';
import '../../features/orders/data/orders_repository.dart';
import '../../features/employees/data/employees_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.read(supabaseClientProvider));
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(supabaseClientProvider));
});

final tablesRepositoryProvider = Provider<TablesRepository>((ref) {
  return TablesRepository(ref.read(supabaseClientProvider));
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.read(supabaseClientProvider));
});

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return EmployeesRepository(ref.read(supabaseClientProvider));
});
