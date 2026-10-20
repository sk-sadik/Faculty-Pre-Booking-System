import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/availability_repository_impl.dart';
import '../../domain/entities/availability.dart';
import '../../domain/repositories/availability_repository.dart';

final availabilityRepositoryProvider =
    Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepositoryImpl(ref.watch(firestoreProvider));
});

/// Live recurring + one-off rules for one faculty member.
final facultyRulesProvider = StreamProvider.autoDispose
    .family<List<AvailabilityRule>, String>((ref, facultyId) {
  return ref.watch(availabilityRepositoryProvider).watchRules(facultyId);
});

/// Live blocked dates for one faculty member.
final facultyBlockedDatesProvider = StreamProvider.autoDispose
    .family<List<BlockedDate>, String>((ref, facultyId) {
  return ref
      .watch(availabilityRepositoryProvider)
      .watchBlockedDates(facultyId);
});

/// Convenience: is [dateKey] ("yyyy-MM-dd") blocked for [facultyId]?
/// Awaits the blocked-dates stream once; UI lists should watch the stream.
final isDateBlockedProvider = FutureProvider.autoDispose
    .family<bool, ({String facultyId, String dateKey})>((ref, args) async {
  final blocked = await ref
      .watch(availabilityRepositoryProvider)
      .watchBlockedDates(args.facultyId)
      .first;
  return blocked.any((b) => b.date == args.dateKey);
});
