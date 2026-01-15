import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/domain/admin_service.dart';

/// Provider für gelöschte Bestellungen (Admin-View)
final deletedOrdersProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(adminServiceProvider).getDeletedOrdersStream();
});

/// Provider für Admin Service
final adminServiceProvider = Provider((ref) {
  return AdminService();
});
