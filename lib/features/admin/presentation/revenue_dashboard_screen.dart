import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

// Real-time Revenue Summary Provider
final revenueSummaryProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final client = Supabase.instance.client;
  
  return client
      .from('daily_revenue_summary_view')
      .stream(primaryKey: ['revenue_date'])
      .map((data) => data.isNotEmpty ? data.first : {})
      .handleError((error) {
        debugPrint('Error streaming revenue summary: $error');
        return {};
      });
});

// Real-time Employee Revenue Provider
final employeeRevenueProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  
  return client
      .from('daily_employee_revenue_view')
      .stream(primaryKey: ['employee_id'])
      .order('total_revenue')
      .map((data) => data.cast<Map<String, dynamic>>())
      .handleError((error) {
        debugPrint('Error streaming employee revenue: $error');
        return [];
      });
});

// Real-time Hourly Revenue Provider
final hourlyRevenueProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  
  return client
      .from('hourly_revenue_view')
      .stream(primaryKey: ['hour'])
      .order('hour')
      .map((data) => data.cast<Map<String, dynamic>>())
      .handleError((error) {
        debugPrint('Error streaming hourly revenue: $error');
        return [];
      });
});

class RevenueDashboardScreen extends ConsumerWidget {
  const RevenueDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(revenueSummaryProvider);
    final employeeAsync = ref.watch(employeeRevenueProvider);
    final hourlyAsync = ref.watch(hourlyRevenueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Umsatz-Dashboard'),
        backgroundColor: Colors.green.shade700,
      ),
      body: summaryAsync.when(
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards - Summary
              _buildSummaryCards(theme, summary),
              const SizedBox(height: 32),

              // Employee Revenue Section
              Text(
                'Umsätze pro Kellner',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              employeeAsync.when(
                data: (employees) => employees.isEmpty
                    ? _buildEmptyState(theme, 'Noch keine Zahlungen heute')
                    : _buildEmployeeRevenueList(theme, employees),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Fehler: $err'),
              ),
              const SizedBox(height: 32),

              // Hourly Revenue Chart
              Text(
                'Umsätze nach Stunde',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              hourlyAsync.when(
                data: (hourly) => hourly.isEmpty
                    ? _buildEmptyState(theme, 'Keine stündlichen Daten')
                    : _buildHourlyRevenueList(theme, hourly),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Fehler: $err'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Fehler: $err')),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, Map<String, dynamic> summary) {
    final totalRevenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalNet = (summary['total_net'] as num?)?.toDouble() ?? 0.0;
    final totalTax = (summary['total_tax'] as num?)?.toDouble() ?? 0.0;
    final orderCount = (summary['total_orders'] as num?)?.toInt() ?? 0;
    final avgOrderValue = (summary['avg_order_value'] as num?)?.toDouble() ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildKpiCard(
          theme: theme,
          title: 'Gesamt Umsatz',
          value: '€ ${totalRevenue.toStringAsFixed(2)}',
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _buildKpiCard(
          theme: theme,
          title: 'Netto',
          value: '€ ${totalNet.toStringAsFixed(2)}',
          icon: Icons.calculate,
          color: Colors.blue,
        ),
        _buildKpiCard(
          theme: theme,
          title: 'MwSt (19%)',
          value: '€ ${totalTax.toStringAsFixed(2)}',
          icon: Icons.receipt,
          color: Colors.orange,
        ),
        _buildKpiCard(
          theme: theme,
          title: 'Bestellungen',
          value: orderCount.toString(),
          icon: Icons.shopping_cart,
          color: Colors.purple,
        ),
        _buildKpiCard(
          theme: theme,
          title: 'Ø Bestellwert',
          value: '€ ${avgOrderValue.toStringAsFixed(2)}',
          icon: Icons.average_quality,
          color: Colors.cyan,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeRevenueList(
    ThemeData theme,
    List<Map<String, dynamic>> employees,
  ) {
    return Column(
      children: [
        ...employees.indexed.map((indexed) {
          final idx = indexed.$1;
          final emp = indexed.$2;
          final revenue = (emp['total_revenue'] as num?)?.toDouble() ?? 0.0;
          final cashRevenue = (emp['cash_revenue'] as num?)?.toDouble() ?? 0.0;
          final cardRevenue = (emp['card_revenue'] as num?)?.toDouble() ?? 0.0;
          final orderCount = (emp['order_count'] as num?)?.toInt() ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getColorForRank(idx),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp['employee_name'] ?? 'Unbekannt',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${emp['employee_name']} • $orderCount Tische',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '€ ${revenue.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentMethod(
                            icon: Icons.wallet,
                            label: 'Bar',
                            amount: cashRevenue,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaymentMethod(
                            icon: Icons.credit_card,
                            label: 'Karte',
                            amount: cardRevenue,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentMethod({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  '€ ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyRevenueList(
    ThemeData theme,
    List<Map<String, dynamic>> hourly,
  ) {
    final maxRevenue = hourly
        .map((h) => (h['revenue'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        ...hourly.map((hour) {
          final time = hour['hour'] as String?;
          final revenue = (hour['revenue'] as num?)?.toDouble() ?? 0.0;
          final barWidth = (revenue / maxRevenue) * 200;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    time?.substring(11, 13) ?? '--',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 24,
                      width: barWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade700,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    '€ ${revenue.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getColorForRank(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber.shade700;
      case 1:
        return Colors.grey.shade400;
      case 2:
        return Colors.orange.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.analytics,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
