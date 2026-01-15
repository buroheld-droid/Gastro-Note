import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/revenue_dashboard_screen.dart';
import '../../features/admin/presentation/deleted_orders_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/kitchen/presentation/kitchen_screen.dart';
import '../../features/kitchen/presentation/kitchen_display_screen.dart';
import '../../features/kitchen/presentation/bar_display_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../services/pin_login_service.dart';


// Mock restaurantId for development - replace with real user ID later
const String _mockRestaurantId = 'restaurant-001';

// Global key for router access
final routerProvider = Provider<GoRouter>((ref) {
  final currentEmployee = ref.watch(currentPinEmployeeProvider);
  
  return GoRouter(
    initialLocation: currentEmployee == null ? '/pin-login' : '/pos',
    redirect: (context, state) {
      final isLoggedIn = currentEmployee != null;
      final isLoginRoute = state.matchedLocation == '/pin-login';

      // Redirect to login if not authenticated
      if (!isLoggedIn && !isLoginRoute) {
        return '/pin-login';
      }

      // Redirect to home if already logged in and trying to access login
      if (isLoggedIn && isLoginRoute) {
        return '/pos';
      }

      return null;
    },
    routes: [
      // Login Route (unprotected)
      GoRoute(
        path: '/pin-login',
        name: 'pin-login',
        builder: (context, state) => const PinLoginScreen(),
      ),
      // Kitchen Display Route (full screen, no shell)
      GoRoute(
        path: '/kitchen-display',
        name: 'kitchen-display',
        builder: (context, state) => const KitchenDisplayScreen(),
      ),
      // Bar Display Route (full screen, no shell)
      GoRoute(
        path: '/bar-display',
        name: 'bar-display',
        builder: (context, state) => const BarDisplayScreen(),
      ),

      // Protected Routes
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pos',
                name: 'pos',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: PosScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                name: 'products',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProductsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kitchen',
                name: 'kitchen',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: KitchenScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/employees',
                name: 'employees',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: EmployeesScreen(restaurantId: _mockRestaurantId),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                name: 'admin',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: AdminDashboardScreen(restaurantId: _mockRestaurantId),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/revenue',
                name: 'revenue',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RevenueDashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deleted-orders',
                name: 'deleted-orders',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DeletedOrdersAdminScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ReportsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class AppRouter {
  // Deprecated - use routerProvider instead
  static GoRouter get router => throw UnimplementedError(
        'Use ref.watch(routerProvider) instead',
      );
}
