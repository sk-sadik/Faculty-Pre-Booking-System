import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/users_repository_impl.dart';
import '../../domain/repositories/users_repository.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepositoryImpl(ref.watch(firestoreProvider));
});

/// Live directory of all faculty (client filters by name/department).
final facultyDirectoryProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchFaculty();
});

/// Live profile doc for any uid (admin + detail screens).
final userDocProvider =
    StreamProvider.autoDispose.family<AppUser?, String>((ref, uid) {
  return ref.watch(usersRepositoryProvider).watchUser(uid);
});

/// Admin: live list of users with one role.
final usersByRoleProvider = StreamProvider.autoDispose
    .family<List<AppUser>, UserRole>((ref, role) {
  return ref.watch(usersRepositoryProvider).watchByRole(role);
});
