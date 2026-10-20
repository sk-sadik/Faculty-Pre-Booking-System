import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/services/seed_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(firestoreProvider));
});

final seedServiceProvider = Provider<SeedService>((ref) {
  return SeedService(
      ref.watch(firestoreProvider), ref.watch(adminRepositoryProvider));
});

/// Live department names (falls back to the static catalog in UI).
final departmentsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(adminRepositoryProvider).watchDepartmentNames();
});

/// Admin analytics: recent appointments across all faculty.
final recentAppointmentsProvider =
    StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchRecent(limit: 500);
});

/// Department entries with doc ids (for admin delete).
final departmentEntriesProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
  return ref.watch(adminRepositoryProvider).departmentEntries();
});
