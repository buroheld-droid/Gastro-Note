import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/category.dart';

// Cached Provider - wird nicht automatisch disposed um Daten zu cachen
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.read(categoriesRepositoryProvider);
  return repository.getAll();
});

// AutoDispose für einzelne Category-Abfragen (werden seltener gebraucht)
final categoryByIdProvider = FutureProvider.autoDispose.family<Category, String>((ref, id) async {
  final repository = ref.read(categoriesRepositoryProvider);
  return repository.getById(id);
});

// Hilfsprovider: Cache invalidieren bei Bedarf
final invalidateCategoriesProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(categoriesProvider);
});
