import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/employee.dart';

// Alle Mitarbeiter pro Restaurant (mit Parameter restaurantId)
final employeesProvider =
    FutureProvider.family<List<Employee>, String>((ref, restaurantId) async {
  final repository = ref.read(employeesRepositoryProvider);
  return repository.getByRestaurant(restaurantId, activeOnly: false);
});

// Nur aktive Mitarbeiter pro Restaurant
final activeEmployeesProvider =
    FutureProvider.family<List<Employee>, String>((ref, restaurantId) async {
  final repository = ref.read(employeesRepositoryProvider);
  return repository.getByRestaurant(restaurantId, activeOnly: true);
});

// Einzelner Mitarbeiter (mit autoDispose)
final employeeByIdProvider = FutureProvider.autoDispose.family<Employee, String>(
    (ref, id) async {
  final repository = ref.read(employeesRepositoryProvider);
  return repository.getById(id);
});

// Invalidation provider
final invalidateEmployeesProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(employeesProvider);
    ref.invalidate(activeEmployeesProvider);
    ref.invalidate(employeeByIdProvider);
  };
});
