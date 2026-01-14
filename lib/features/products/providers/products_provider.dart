import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/product.dart';

// Cached - alle Produkte (selten verwendet, aber gut für Suche/Reports)
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.read(productsRepositoryProvider);
  return repository.getAll();
});

// Cached per Category - häufig verwendet beim Order Screen
// Kein autoDispose, da Kategorien oft gewechselt werden
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>((ref, categoryId) async {
  final repository = ref.read(productsRepositoryProvider);
  return repository.getByCategory(categoryId);
});

// AutoDispose für einzelne Produkte (selten gebraucht)
final productByIdProvider = FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  final repository = ref.read(productsRepositoryProvider);
  return repository.getById(id);
});

// Cache invalidieren
final invalidateProductsProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(productsProvider);
    ref.invalidate(productsByCategoryProvider);
  };
});
