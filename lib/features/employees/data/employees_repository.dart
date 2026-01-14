import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/employee.dart';

class EmployeesRepository {
  final SupabaseClient _client;

  EmployeesRepository(this._client);

  /// Get current authenticated user's employee record
  Future<Employee?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('employees')
          .select()
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Fehler beim Laden des aktuellen Nutzers: $e');
    }
  }

  /// Get all employees for a restaurant
  /// Automatically uses RLS via authenticated user
  Future<List<Employee>> getByRestaurant(
    String restaurantId, {
    bool activeOnly = true,
  }) async {
    try {
      var query = _client
          .from('employees')
          .select()
          .eq('restaurant_id', restaurantId);

      if (activeOnly) {
        query = query.eq('status', 'active').isFilter('deleted_at', null);
      }

      final response = await query.order('first_name').order('last_name');

      return (response as List).map((json) => Employee.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Fehler beim Laden der Mitarbeiter: $e');
    }
  }

  /// Get single employee by ID
  Future<Employee> getById(String id) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('id', id)
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Mitarbeiter nicht gefunden: $e');
    }
  }

  /// Create a new employee
  Future<Employee> create(Employee employee) async {
    try {
      final response = await _client
          .from('employees')
          .insert(employee.toJson())
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Fehler beim Erstellen des Mitarbeiters: $e');
    }
  }

  /// Update an existing employee
  Future<Employee> update(Employee employee) async {
    try {
      final response = await _client
          .from('employees')
          .update(employee.toJson())
          .eq('id', employee.id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Fehler beim Aktualisieren des Mitarbeiters: $e');
    }
  }

  /// Soft delete (set deleted_at)
  Future<void> delete(String id) async {
    try {
      await _client
          .from('employees')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw Exception('Fehler beim Löschen des Mitarbeiters: $e');
    }
  }

  /// Restore a deleted employee
  Future<void> restore(String id) async {
    try {
      await _client.from('employees').update({'deleted_at': null}).eq('id', id);
    } catch (e) {
      throw Exception('Fehler beim Wiederherstellen des Mitarbeiters: $e');
    }
  }

  /// Change employee status
  Future<Employee> updateStatus(String id, EmployeeStatus status) async {
    try {
      final response = await _client
          .from('employees')
          .update({'status': status.toShortString()})
          .eq('id', id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Fehler beim Ändern des Status: $e');
    }
  }

  /// Change employee role
  Future<Employee> updateRole(String id, EmployeeRole role) async {
    try {
      final response = await _client
          .from('employees')
          .update({'role': role.toShortString()})
          .eq('id', id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Fehler beim Ändern der Rolle: $e');
    }
  }
}
