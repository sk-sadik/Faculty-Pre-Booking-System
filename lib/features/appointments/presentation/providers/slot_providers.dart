import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_utils.dart';
import '../../../availability/presentation/providers/availability_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../domain/slot_generator.dart';
import 'appointment_providers.dart';

/// Free slots for one faculty on one day ("yyyy-MM-dd"), combining the
/// faculty's rules, blocked dates, existing bookings and booking settings.
/// Returns an [AsyncValue] so UIs can render loading/error/empty states.
final freeSlotsProvider = Provider.autoDispose.family<
    AsyncValue<List<TimeSlot>>, ({String facultyId, String dateKey})>(
    (ref, args) {
  final rules = ref.watch(facultyRulesProvider(args.facultyId));
  final blocked = ref.watch(facultyBlockedDatesProvider(args.facultyId));
  final appts = ref.watch(facultyDayAppointmentsProvider(args));
  final faculty = ref.watch(userDocProvider(args.facultyId));

  final loading =
      rules.isLoading || blocked.isLoading || appts.isLoading || faculty.isLoading;
  try {
    final r = rules.requireValue;
    final b = blocked.requireValue;
    final a = appts.requireValue;
    final f = faculty.requireValue;
    final slots = const SlotGenerator().generate(
      date: parseDateKey(args.dateKey),
      rules: r,
      blocked: b,
      existing: a,
      maxPerDay: f?.effectiveMaxPerDay ?? 8,
      bufferMinutes: f?.effectiveBufferMinutes ?? 10,
    );
    return AsyncValue.data(slots);
  } catch (e, s) {
    if (loading) return const AsyncValue.loading();
    return AsyncValue.error(e, s);
  }
});

/// Whether a faculty member looks bookable today: walk-in flag or any
/// active rule covering today. Feeds the directory badge + filter.
final facultyAvailableTodayProvider =
    FutureProvider.autoDispose.family<bool, String>(
        (ref, facultyId) async {
  final rules = await ref.watch(facultyRulesProvider(facultyId).future);
  final user = await ref.watch(userDocProvider(facultyId).future);
  if (user?.isAvailableNow == true) return true;
  return rules.any((r) => r.appliesTo(DateTime.now()));
});
