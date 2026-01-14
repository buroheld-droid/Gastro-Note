class RestaurantTable {
  final String id;
  final String tableNumber;
  final String area; // 'indoor', 'outdoor', 'bar'
  final int capacity;
  final String status; // 'available', 'occupied', 'reserved'
  final String? currentOrderId;
  final bool isActive;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.area,
    required this.capacity,
    required this.status,
    this.currentOrderId,
    required this.isActive,
    this.notes,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'] as String,
      tableNumber: json['table_number'] as String,
      area: json['area'] as String,
      capacity: json['capacity'] as int,
      status: json['status'] as String? ?? 'available',
      currentOrderId: json['current_order_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_number': tableNumber,
      'area': area,
      'capacity': capacity,
      'status': status,
      'current_order_id': currentOrderId,
      'is_active': isActive,
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? area,
    int? capacity,
    String? status,
    String? currentOrderId,
    bool? isActive,
    String? notes,
    int? sortOrder,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      area: area ?? this.area,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt,
    );
  }
}
