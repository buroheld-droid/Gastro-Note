import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/restaurant_table.dart';

// Cached - häufig verwendet im POS Table Screen
// Muss manuell invalidiert werden nach Order-Änderungen
final tablesProvider = FutureProvider<List<RestaurantTable>>((ref) async {
  final repository = ref.read(tablesRepositoryProvider);
  return repository.getAll();
});

// Cached per Area
final tablesByAreaProvider = FutureProvider.family<List<RestaurantTable>, String>((ref, area) async {
  final repository = ref.read(tablesRepositoryProvider);
  return repository.getByArea(area);
});

// AutoDispose für einzelne Tisch-Abfragen
final tableByIdProvider = FutureProvider.autoDispose.family<RestaurantTable, String>((ref, id) async {
  final repository = ref.read(tablesRepositoryProvider);
  return repository.getById(id);
});

// Cache invalidieren nach Order-Änderungen
final invalidateTablesProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(tablesProvider);
    ref.invalidate(tablesByAreaProvider);
  };
});
