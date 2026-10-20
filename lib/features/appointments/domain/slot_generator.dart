import 'package:equatable/equatable.dart';

import '../../../../core/utils/time_utils.dart';
import '../../availability/domain/entities/availability.dart';
import 'appointment_rules.dart';
import 'entities/appointment.dart';

/// A single bookable window on a day, in minutes since midnight.
class TimeSlot extends Equatable {
  const TimeSlot({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  String get label => '${formatHm(startMinutes)} – ${formatHm(endMinutes)}';

  @override
  List<Object?> get props => [startMinutes, endMinutes];
}

/// Pure-Dart free-slot computation:
///
/// free = availability windows for the day
///   minus blocked dates
///   minus existing pending/approved/rescheduled appointments
///   minus past times (when generating for today)
///   minus buffer zones around existing appointments
///   gated by maxPerDay (a full day yields no slots).
class SlotGenerator {
  const SlotGenerator();

  List<TimeSlot> generate({
    required DateTime date,
    required List<AvailabilityRule> rules,
    required List<BlockedDate> blocked,
    required List<Appointment> existing,
    required int maxPerDay,
    required int bufferMinutes,
    DateTime? now,
  }) {
    final key = dateKey(date);
    final today = now ?? DateTime.now();

    // Blocked day → nothing bookable.
    if (blocked.any((b) => b.date == key)) return const [];

    // Day full → nothing bookable.
    final bookedCount = existing
        .where((a) => a.date == key && a.isBlocking)
        .length;
    if (bookedCount >= maxPerDay) return const [];

    // Occupied ranges on this day, widened by the buffer on both sides.
    final occupied = <TimeSlot>[];
    for (final a in existing) {
      if (a.date != key || !a.isBlocking) continue;
      occupied.add(TimeSlot(
        startMinutes: a.startMinutes - bufferMinutes,
        endMinutes: a.endMinutes + bufferMinutes,
      ));
    }

    final isToday = isSameDay(date, today);
    final nowMinutes = today.hour * 60 + today.minute;

    final out = <TimeSlot>[];
    for (final rule in rules) {
      if (!rule.appliesTo(date)) continue;
      var cursor = rule.startMinutes;
      while (cursor + rule.slotDuration <= rule.endMinutes) {
        final end = cursor + rule.slotDuration;
        // Skip slots that already started (today only).
        if (!isToday || cursor > nowMinutes) {
          final overlaps = occupied.any((o) =>
              timesOverlap(cursor, end, o.startMinutes, o.endMinutes));
          if (!overlaps) {
            out.add(TimeSlot(startMinutes: cursor, endMinutes: end));
          }
        }
        cursor = end;
      }
    }
    out.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return out;
  }
}
