import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tables/domain/restaurant_table.dart';
import '../../tables/providers/tables_provider.dart';
import 'table_order_screen.dart';
import 'order_detail_screen.dart';

class PosTableScreen extends ConsumerStatefulWidget {
  const PosTableScreen({super.key});

  @override
  ConsumerState<PosTableScreen> createState() => _PosTableScreenState();
}

class _PosTableScreenState extends ConsumerState<PosTableScreen> {
  String _selectedArea = 'all';

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 768;

    return Padding(
      padding: EdgeInsets.all(isPhone ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tischübersicht', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Alle')),
                      ButtonSegment(value: 'indoor', label: Text('Innen')),
                      ButtonSegment(value: 'outdoor', label: Text('Außen')),
                      ButtonSegment(value: 'bar', label: Text('Bar')),
                    ],
                    selected: {_selectedArea},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedArea = selection.first;
                      });
                    },
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: Text('Tischübersicht', style: theme.textTheme.titleLarge)),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Alle')),
                        ButtonSegment(value: 'indoor', label: Text('Innen')),
                        ButtonSegment(value: 'outdoor', label: Text('Außen')),
                        ButtonSegment(value: 'bar', label: Text('Bar')),
                      ],
                      selected: {_selectedArea},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          _selectedArea = selection.first;
                        });
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          Expanded(
            child: tablesAsync.when(
              data: (tables) {
                final filteredTables = _selectedArea == 'all'
                    ? tables
                    : tables.where((t) => t.area == _selectedArea).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount;
                    if (width < 420) {
                      crossAxisCount = 2; // phones portrait
                    } else if (width < 720) {
                      crossAxisCount = 3; // phones landscape / small tablets
                    } else {
                      crossAxisCount = 4; // larger screens
                    }

                    double childAspectRatio;
                    if (width < 420) {
                      childAspectRatio = 0.9; // make tiles taller on small screens
                    } else if (width < 720) {
                      childAspectRatio = 1.0;
                    } else {
                      childAspectRatio = 1.1;
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: filteredTables.length,
                      itemBuilder: (context, index) {
                        final table = filteredTables[index];
                        return _TableCard(
                          table: table,
                          onTap: () => _openTable(context, table),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Fehler: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTable(BuildContext context, RestaurantTable table) {
    final screen = (table.status == 'occupied' && table.currentOrderId != null)
        ? OrderDetailScreen(table: table)
        : TableOrderScreen(table: table);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.onTap});

  final RestaurantTable table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(table.status);
    final areaLabel = _getAreaLabel(table.area);

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  table.tableNumber,
                  maxLines: 1,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                areaLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text('${table.capacity}', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 4),
              Chip(
                label: Text(_getStatusLabel(table.status)),
                backgroundColor: statusColor.withValues(alpha: 0.2),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                padding: EdgeInsets.zero,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF22C55E);
      case 'occupied':
        return const Color(0xFFEF4444);
      case 'reserved':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Frei';
      case 'occupied':
        return 'Besetzt';
      case 'reserved':
        return 'Reserviert';
      default:
        return 'Unbekannt';
    }
  }

  String _getAreaLabel(String area) {
    switch (area) {
      case 'indoor':
        return 'Innen';
      case 'outdoor':
        return 'Außen';
      case 'bar':
        return 'Bar';
      default:
        return area;
    }
  }
}
