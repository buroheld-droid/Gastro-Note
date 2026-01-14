// Daily revenue statistics for a restaurant
class DailyRevenue {
  final String date;
  final double totalRevenue;
  final double totalTax;
  final double netRevenue;
  final int orderCount;
  final int transactionCount;
  final DateTime createdAt;

  DailyRevenue({
    required this.date,
    required this.totalRevenue,
    required this.totalTax,
    required this.netRevenue,
    required this.orderCount,
    required this.transactionCount,
    required this.createdAt,
  });

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    return DailyRevenue(
      date: json['date'] as String,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
      netRevenue: (json['net_revenue'] as num?)?.toDouble() ?? 0.0,
      orderCount: json['order_count'] as int? ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Employee performance metrics
class EmployeeRevenue {
  final String employeeId;
  final String employeeName;
  final double totalRevenue;
  final int orderCount;
  final double avgOrderValue;
  final bool isActive;
  final DateTime lastTransaction;

  EmployeeRevenue({
    required this.employeeId,
    required this.employeeName,
    required this.totalRevenue,
    required this.orderCount,
    required this.avgOrderValue,
    required this.isActive,
    required this.lastTransaction,
  });

  factory EmployeeRevenue.fromJson(Map<String, dynamic> json) {
    final totalRevenue = (json['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final orderCount = json['order_count'] as int? ?? 0;

    return EmployeeRevenue(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String? ?? 'Unknown',
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      avgOrderValue: orderCount > 0 ? totalRevenue / orderCount : 0.0,
      isActive: json['is_active'] as bool? ?? false,
      lastTransaction: DateTime.parse(
        json['last_transaction'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// Shift summary (optional für späteren Ausbau)
class ShiftSummary {
  final String shiftId;
  final String employeeId;
  final String employeeName;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalRevenue;
  final int transactionCount;
  final double tips;

  ShiftSummary({
    required this.shiftId,
    required this.employeeId,
    required this.employeeName,
    required this.startTime,
    this.endTime,
    required this.totalRevenue,
    required this.transactionCount,
    required this.tips,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      shiftId: json['shift_id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String? ?? 'Unknown',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      tips: (json['tips'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

