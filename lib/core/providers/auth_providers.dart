import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Aktueller authentifizierter User
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// Restaurant-ID des aktuellen Users (aus employees Tabelle)
final userRestaurantIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final client = Supabase.instance.client;
    final response = await client
        .from('employees')
        .select('restaurant_id')
        .eq('email', user.email ?? '')
        .or('id.eq.${user.id}')
        .single();

    return response['restaurant_id'] as String?;
  } catch (e) {
    return null; // User ist kein Employee
  }
});

// Current Employee Record (mit Role, Status, etc.)
final currentEmployeeProvider = FutureProvider((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final client = Supabase.instance.client;
    final response = await client
        .from('employees')
        .select()
        .eq('email', user.email ?? '')
        .or('id.eq.${user.id}')
        .single();

    return response;
  } catch (e) {
    return null;
  }
});

// User's Role (aus Employee record)
final userRoleProvider = FutureProvider<String?>((ref) async {
  final employee = await ref.watch(currentEmployeeProvider.future);
  return employee?['role'] as String?;
});

// Ist User ein Admin/Inhaber?
final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == 'Inhaber';
});

// Ist User ein Koch?
final isKochProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == 'Koch';
});

// Ist User Service (Kellner/Barkeeper)?
final isServiceProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return ['Kellner', 'Barkeeper'].contains(role);
});

// User Status (active/inactive/on_leave)
final userStatusProvider = FutureProvider<String?>((ref) async {
  final employee = await ref.watch(currentEmployeeProvider.future);
  return employee?['status'] as String?;
});

// Ist User aktiv heute?
final isUserActiveProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(userStatusProvider.future);
  return status == 'active';
});

// Invalidation
final invalidateAuthProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(currentUserProvider);
    ref.invalidate(userRestaurantIdProvider);
    ref.invalidate(currentEmployeeProvider);
    ref.invalidate(userRoleProvider);
    ref.invalidate(isAdminProvider);
    ref.invalidate(isKochProvider);
    ref.invalidate(isServiceProvider);
    ref.invalidate(userStatusProvider);
    ref.invalidate(isUserActiveProvider);
  };
});
