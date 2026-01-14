import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../employees/domain/employee.dart';
import '../../employees/providers/employees_provider.dart';
import '../domain/revenue_models.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, required this.restaurantId});
  final String restaurantId;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  // Mock data for now - später mit echtem Repository
  late DailyRevenue _todayRevenue;
  late List<EmployeeRevenue> _employeeRevenues;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _todayRevenue = DailyRevenue(
      date: now.toIso8601String().split('T')[0],
      totalRevenue: 1250.50,
      totalTax: 199.50,
      netRevenue: 1051.00,
      orderCount: 47,
      transactionCount: 52,
      createdAt: now,
    );

    _employeeRevenues = [
      EmployeeRevenue(
        employeeId: 'emp-001',
        employeeName: 'Anna Schmidt',
        totalRevenue: 520.00,
        orderCount: 24,
        avgOrderValue: 21.67,
        isActive: true,
        lastTransaction: now.subtract(const Duration(minutes: 5)),
      ),
      EmployeeRevenue(
        employeeId: 'emp-002',
        employeeName: 'Max Mustermann',
        totalRevenue: 380.50,
        orderCount: 18,
        avgOrderValue: 21.14,
        isActive: true,
        lastTransaction: now.subtract(const Duration(minutes: 12)),
      ),
      EmployeeRevenue(
        employeeId: 'emp-003',
        employeeName: 'Tom Barmann',
        totalRevenue: 350.00,
        orderCount: 5,
        avgOrderValue: 70.00,
        isActive: false,
        lastTransaction: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employeesAsync = ref.watch(employeesProvider(widget.restaurantId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Admin Dashboard', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),

          // KPI Cards - Row 1
          Row(
            children: [
              Expanded(
                child: _KPICard(
                  title: 'Tageseinnahmen',
                  value: '€${_todayRevenue.totalRevenue.toStringAsFixed(2)}',
                  subtitle: 'Brutto',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KPICard(
                  title: 'Netto',
                  value: '€${_todayRevenue.netRevenue.toStringAsFixed(2)}',
                  subtitle: 'Nach MwSt',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KPICard(
                  title: 'MwSt',
                  value: '€${_todayRevenue.totalTax.toStringAsFixed(2)}',
                  subtitle: 'Gesamt',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI Cards - Row 2
          Row(
            children: [
              Expanded(
                child: _KPICard(
                  title: 'Bestellungen',
                  value: '${_todayRevenue.orderCount}',
                  subtitle: 'Heute',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KPICard(
                  title: 'Transaktionen',
                  value: '${_todayRevenue.transactionCount}',
                  subtitle: 'Heute',
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KPICard(
                  title: 'Ø pro Bestellung',
                  value:
                      '€${(_todayRevenue.totalRevenue / _todayRevenue.orderCount).toStringAsFixed(2)}',
                  subtitle: 'Durchschnitt',
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Mitarbeiter Übersicht
          Text('Mitarbeiter Übersicht', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          employeesAsync.when(
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('Keine Mitarbeiter'));
              }
              return _EmployeeStatusPanel(
                employees: employees,
                revenues: _employeeRevenues,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
          ),
          const SizedBox(height: 24),

          // Employee Revenue Tabelle
          Text(
            'Umsatz pro Mitarbeiter (heute)',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _EmployeeRevenueTable(revenues: _employeeRevenues),
        ],
      ),
    );
  }
}

/// KPI-Karte für Kennzahlen
class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Panel zum Aktivieren/Deaktivieren von Mitarbeitern
class _EmployeeStatusPanel extends ConsumerWidget {
  final List<Employee> employees;
  final List<EmployeeRevenue> revenues;

  const _EmployeeStatusPanel({required this.employees, required this.revenues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Group by status
    final active = employees.where((e) => e.status == EmployeeStatus.active);
    final inactive = employees.where(
      (e) => e.status == EmployeeStatus.inactive,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aktive Mitarbeiter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Heute Aktiv (${active.length})',
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  'Inaktiv (${inactive.length})',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Active list
                Expanded(
                  child: Column(
                    children: [
                      ...active.map(
                        (e) => _EmployeeStatusTile(employee: e, isActive: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Inactive list
                Expanded(
                  child: Column(
                    children: [
                      ...inactive.map(
                        (e) =>
                            _EmployeeStatusTile(employee: e, isActive: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeStatusTile extends ConsumerWidget {
  final Employee employee;
  final bool isActive;

  const _EmployeeStatusTile({required this.employee, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    employee.role.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (newValue) async {
                final repo = ref.read(employeesRepositoryProvider);
                final newStatus = newValue
                    ? EmployeeStatus.active
                    : EmployeeStatus.inactive;
                try {
                  await repo.updateStatus(employee.id, newStatus);
                  ref.read(invalidateEmployeesProvider)();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabelle mit Umsatzdetails pro Mitarbeiter
class _EmployeeRevenueTable extends StatelessWidget {
  final List<EmployeeRevenue> revenues;

  const _EmployeeRevenueTable({required this.revenues});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Status'), numeric: false),
            DataColumn(label: Text('Umsatz'), numeric: true),
            DataColumn(label: Text('Bestellungen'), numeric: true),
            DataColumn(label: Text('Ø Wert'), numeric: true),
            DataColumn(label: Text('Zuletzt')),
          ],
          rows: revenues
              .map(
                (revenue) => DataRow(
                  cells: [
                    DataCell(Text(revenue.employeeName)),
                    DataCell(
                      Chip(
                        label: Text(
                          revenue.isActive ? 'Aktiv' : 'Inaktiv',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: revenue.isActive
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    DataCell(
                      Text(
                        '€${revenue.totalRevenue.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text('${revenue.orderCount}')),
                    DataCell(
                      Text('€${revenue.avgOrderValue.toStringAsFixed(2)}'),
                    ),
                    DataCell(
                      Text(
                        _formatTime(revenue.lastTransaction),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Gerade eben';
    } else if (diff.inMinutes < 60) {
      return 'vor ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'vor ${diff.inHours}h';
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }
}

// Provider für invalidieren
final invalidateAdminDashboardProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(employeesProvider);
  };
});
