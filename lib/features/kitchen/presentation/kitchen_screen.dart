import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_status.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  // Filter: welche Stati anzeigen
  OrderStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Küche', style: theme.textTheme.headlineSmall),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  _buildStatusFilterChip(context, null, 'Alle'),
                  _buildStatusFilterChip(
                    context,
                    OrderStatus.pending,
                    OrderStatus.pending.label,
                  ),
                  _buildStatusFilterChip(
                    context,
                    OrderStatus.inProgress,
                    OrderStatus.inProgress.label,
                  ),
                  _buildStatusFilterChip(
                    context,
                    OrderStatus.ready,
                    OrderStatus.ready.label,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _KitchenOrdersView(filterStatus: _filterStatus)),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(
    BuildContext context,
    OrderStatus? status,
    String label,
  ) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = status),
    );
  }
}

class _KitchenOrdersView extends ConsumerStatefulWidget {
  const _KitchenOrdersView({required this.filterStatus});
  final OrderStatus? filterStatus;

  @override
  ConsumerState<_KitchenOrdersView> createState() => _KitchenOrdersViewState();
}

class _KitchenOrdersViewState extends ConsumerState<_KitchenOrdersView> {
  // Auto-refresh every 5 seconds for real-time updates
  late Future<void> _refreshFuture;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshFuture = Future.delayed(const Duration(seconds: 5)).then((_) {
      if (mounted) {
        setState(() => _startAutoRefresh());
      }
    });
  }

  @override
  void dispose() {
    _refreshFuture.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Implement real data fetching from repository
    // For now, placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Küchen-Display wird geladen...'),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
          const SizedBox(height: 32),
          Text(
            'Filter: ${widget.filterStatus?.label ?? "Alle"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
