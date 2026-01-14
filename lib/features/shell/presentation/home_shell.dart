import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/pin_login_service.dart';
import '../../employees/domain/employee.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Alle möglichen Navigation Items
  static const _allNavItems = [
    _NavItem('Kasse', Icons.point_of_sale_rounded, '/pos', {
      EmployeeRole.owner,
      EmployeeRole.waiter,
      EmployeeRole.bartender,
      EmployeeRole.manager,
    }),
    _NavItem('Produkte', Icons.grid_view_rounded, '/products', {
      EmployeeRole.owner,
      EmployeeRole.manager,
    }),
    _NavItem('Küche', Icons.restaurant_rounded, '/kitchen', {
      EmployeeRole.owner,
      EmployeeRole.chef, // Koch sieht nur Küche
      EmployeeRole.waiter, // Kellner sieht auch offene Bestellungen
      EmployeeRole.bartender, // Barkeeper sieht auch Bestellungen
      EmployeeRole.manager,
    }),
    _NavItem('Mitarbeiter', Icons.badge_rounded, '/employees', {
      EmployeeRole.owner,
      EmployeeRole.manager,
    }),
    _NavItem('Admin', Icons.dashboard_rounded, '/admin', {
      EmployeeRole.owner,
      EmployeeRole.manager,
    }),
    _NavItem('Berichte', Icons.insert_chart_outlined_rounded, '/reports', {
      EmployeeRole.owner,
      EmployeeRole.manager,
    }),
    _NavItem('Einstellungen', Icons.tune_rounded, '/settings', {
      EmployeeRole.owner,
    }),
  ];

  List<_NavItem> _getVisibleItems(EmployeeRole? role) {
    if (role == null) return [];

    // Filter items basierend auf role
    return _allNavItems
        .where((item) => item.allowedRoles.contains(role))
        .toList();
  }

  void _onDestinationSelected(
    BuildContext context,
    int visualIndex,
    List<_NavItem> visibleItems,
  ) {
    // Map visual index to actual route
    final selectedItem = visibleItems[visualIndex];
    context.go(selectedItem.path);
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    // Clear current employee
    ref.read(currentPinEmployeeProvider.notifier).state = null;
    // Navigate to login
    context.go('/pin-login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentEmployee = ref.watch(currentPinEmployeeProvider);
    final visibleItems = _getVisibleItems(currentEmployee?.role);

    // Find current index from path
    final currentPath = GoRouterState.of(context).matchedLocation;
    final currentIndex = visibleItems.indexWhere(
      (item) => item.path == currentPath,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          currentIndex >= 0 && currentIndex < visibleItems.length
              ? visibleItems[currentIndex].label
              : 'Gastro-Note',
        ),
        actions: [
          // Mitarbeiter Info
          if (currentEmployee != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    currentEmployee.firstName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text(
                  '${currentEmployee.firstName} (${currentEmployee.role.label})',
                  style: const TextStyle(fontSize: 13),
                ),
                backgroundColor: theme.colorScheme.surface,
                side: const BorderSide(color: Colors.white10),
              ),
            ),

          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Abmelden',
            onPressed: () => _handleLogout(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: shell,
        ),
      ),
      bottomNavigationBar: visibleItems.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: currentIndex.clamp(0, visibleItems.length - 1),
              destinations: visibleItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index, visibleItems),
            ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.path, this.allowedRoles);
  final String label;
  final IconData icon;
  final String path;
  final Set<EmployeeRole> allowedRoles;
}
