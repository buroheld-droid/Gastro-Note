enum EmployeeRole {
  owner('Inhaber'),
  waiter('Kellner'),
  bartender('Barkeeper'),
  chef('Koch'),
  manager('Manager');

  final String label;
  const EmployeeRole(this.label);

  factory EmployeeRole.fromString(String value) {
    final normalized = value.toLowerCase().trim();
    return EmployeeRole.values.firstWhere(
      (e) => e.name == normalized || e.label.toLowerCase() == normalized,
      orElse: () => EmployeeRole.waiter,
    );
  }

  String toShortString() => name;
}

enum EmployeeStatus {
  active('Aktiv'),
  inactive('Inaktiv'),
  onLeave('Abwesend');

  final String label;
  const EmployeeStatus(this.label);

  factory EmployeeStatus.fromString(String value) {
    return EmployeeStatus.values.firstWhere(
      (e) => e.name == value.replaceAll('_', '').toLowerCase(),
      orElse: () => EmployeeStatus.active,
    );
  }

  String toShortString() => name;
}

class Employee {
  final String id;
  final String restaurantId;
  final String employeeNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? pinCode;
  final EmployeeRole role;
  final EmployeeStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Employee({
    required this.id,
    required this.restaurantId,
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.pinCode,
    required this.role,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String? ?? '',
      employeeNumber: json['employee_number'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      pinCode: json['pin_code'] as String?,
      role: EmployeeRole.fromString(json['role'] as String? ?? 'waiter'),
      status: EmployeeStatus.fromString(json['status'] as String? ?? 'active'),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'employee_number': employeeNumber,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'pin_code': pinCode,
    'role': role.toShortString(),
    'status': status.toShortString(),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  Employee copyWith({
    String? id,
    String? restaurantId,
    String? employeeNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? pinCode,
    EmployeeRole? role,
    EmployeeStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => Employee(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    employeeNumber: employeeNumber ?? this.employeeNumber,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    pinCode: pinCode ?? this.pinCode,
    role: role ?? this.role,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
