import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/employees/domain/employee.dart';

/// PIN Login Service - Produktionsreif mit Security Features
class PinLoginService {
  final SupabaseClient _client;

  PinLoginService(this._client);

  static const int maxAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 5);
  final Map<String, _LoginAttempt> _attempts = {};

  /// PIN Login mit attempt limiting und lockout
  Future<Employee?> loginWithPin(String pin) async {
    // Validate PIN format
    if (pin.length < 4 || pin.length > 6) {
      throw ArgumentError('PIN muss 4-6 Ziffern lang sein');
    }

    // Check if locked out
    final lockout = _checkLockout(pin);
    if (lockout != null) {
      throw PinLockoutException(
        'Zu viele Fehlversuche. Bitte warte ${lockout.inSeconds} Sekunden.',
      );
    }

    try {
      // Query employee by PIN
      final result = await _client
          .from('employees')
          .select('*, roles(*)')
          .eq('pin_code', pin)
          .eq('is_active', true)
          .maybeSingle();

      if (result == null) {
        _recordFailedAttempt(pin);
        throw PinAuthException('Ungültiger PIN-Code');
      }

      // Reset attempts on success
      _attempts.remove(pin);

      // Map to Employee model
      return Employee(
        id: result['id'] as String,
        employeeNumber: result['employee_number'] as String,
        firstName: result['first_name'] as String,
        lastName: result['last_name'] as String,
        email: result['email'] as String?,
        phone: result['phone'] as String?,
        role: _mapRole(result['role'] as String?),
        status: _mapStatus(result['status'] as String?),
        restaurantId: result['restaurant_id'] as String? ?? '',
        notes: result['notes'] as String?,
        createdAt: DateTime.parse(result['created_at'] as String),
        updatedAt: DateTime.parse(result['updated_at'] as String),
      );
    } catch (e) {
      if (e is PinAuthException || e is PinLockoutException) rethrow;
      throw PinAuthException('Login fehlgeschlagen: ${e.toString()}');
    }
  }

  /// Check lockout status
  Duration? _checkLockout(String pin) {
    final attempt = _attempts[pin];
    if (attempt == null) return null;

    if (attempt.count >= maxAttempts) {
      final elapsed = DateTime.now().difference(attempt.lastAttempt);
      if (elapsed < lockoutDuration) {
        return lockoutDuration - elapsed;
      } else {
        // Lockout expired, reset
        _attempts.remove(pin);
        return null;
      }
    }
    return null;
  }

  /// Record failed login attempt
  void _recordFailedAttempt(String pin) {
    final existing = _attempts[pin];
    if (existing == null) {
      _attempts[pin] = _LoginAttempt(count: 1, lastAttempt: DateTime.now());
    } else {
      _attempts[pin] = _LoginAttempt(
        count: existing.count + 1,
        lastAttempt: DateTime.now(),
      );
    }
  }

  /// Get remaining attempts
  int getRemainingAttempts(String pin) {
    final attempt = _attempts[pin];
    if (attempt == null) return maxAttempts;
    return (maxAttempts - attempt.count).clamp(0, maxAttempts);
  }

  /// Clear all attempts (admin function)
  void clearAttempts() {
    _attempts.clear();
  }

  EmployeeRole _mapRole(String? role) {
    if (role == null) return EmployeeRole.waiter;
    return EmployeeRole.fromString(role);
  }

  EmployeeStatus _mapStatus(String? status) {
    if (status == null) return EmployeeStatus.active;
    return EmployeeStatus.fromString(status);
  }
}

class _LoginAttempt {
  final int count;
  final DateTime lastAttempt;

  _LoginAttempt({required this.count, required this.lastAttempt});
}

class PinAuthException implements Exception {
  final String message;
  PinAuthException(this.message);

  @override
  String toString() => message;
}

class PinLockoutException implements Exception {
  final String message;
  PinLockoutException(this.message);

  @override
  String toString() => message;
}

/// Provider für PIN Login Service
final pinLoginServiceProvider = Provider<PinLoginService>((ref) {
  return PinLoginService(Supabase.instance.client);
});

/// Provider für aktuell eingeloggten Mitarbeiter via PIN
final currentPinEmployeeProvider = StateProvider<Employee?>((ref) => null);
