import '../../../../core/utils/time_utils.dart';
import 'entities/appointment.dart';

/// Pure-Dart booking business rules. No Flutter/Firebase imports — unit-test
/// the behavior here, then call it from repositories and UI.

/// Thrown when a status change violates the allowed transition graph.
class AppointmentRuleViolation implements Exception {
  const AppointmentRuleViolation(this.message);
  final String message;
  @override
  String toString() => 'AppointmentRuleViolation: $message';
}

/// Thrown when a slot cannot be booked (taken, overlapping, day full, …).
class BookingConflict implements Exception {
  const BookingConflict(this.message);
  final String message;
  @override
  String toString() => 'BookingConflict: $message';
}

/// Hours before start until which a student may still cancel.
const int studentCancelCutoffHours = 2;

/// Allowed status transitions:
/// pending → approved / rejected / cancelled
/// approved → rescheduled / completed / cancelled / no_show
/// rescheduled → approved / cancelled
bool canTransition(AppointmentStatus from, AppointmentStatus to) {
  switch (from) {
    case AppointmentStatus.pending:
      return to == AppointmentStatus.approved ||
          to == AppointmentStatus.rejected ||
          to == AppointmentStatus.cancelled;
    case AppointmentStatus.approved:
      return to == AppointmentStatus.rescheduled ||
          to == AppointmentStatus.completed ||
          to == AppointmentStatus.cancelled ||
          to == AppointmentStatus.noShow;
    case AppointmentStatus.rescheduled:
      return to == AppointmentStatus.approved ||
          to == AppointmentStatus.cancelled;
    case AppointmentStatus.rejected:
    case AppointmentStatus.cancelled:
    case AppointmentStatus.completed:
    case AppointmentStatus.noShow:
      return false;
  }
}

/// Same as [canTransition] but throws a descriptive [AppointmentRuleViolation].
void requireTransition(AppointmentStatus from, AppointmentStatus to) {
  if (!canTransition(from, to)) {
    throw AppointmentRuleViolation(
        'Cannot move appointment from ${from.value} to ${to.value}.');
  }
}

/// Half-open overlap check on minutes-since-midnight ranges.
bool timesOverlap(int aStart, int aEnd, int bStart, int bEnd) =>
    aStart < bEnd && bStart < aEnd;

/// Whether [candidate] overlaps any blocking appointment in [existing] on
/// the same date. Used to stop a student double-booking themselves.
bool studentHasOverlap({
  required List<Appointment> existing,
  required String date,
  required int startMinutes,
  required int endMinutes,
  String? excludeId,
}) {
  for (final a in existing) {
    if (a.id == excludeId) continue;
    if (a.date != date || !a.isBlocking) continue;
    if (timesOverlap(
        startMinutes, endMinutes, a.startMinutes, a.endMinutes)) {
      return true;
    }
  }
  return false;
}

/// Parses a slot's start into a [DateTime], or null when malformed.
DateTime? trySlotStart(String date, String startTime) {
  try {
    return combine(parseDateKey(date), parseHm(startTime));
  } catch (_) {
    return null;
  }
}

/// Students may cancel only when more than [studentCancelCutoffHours] remain
/// before the meeting starts.
bool canStudentCancel({
  required String date,
  required String startTime,
  required DateTime now,
}) {
  final start = trySlotStart(date, startTime);
  if (start == null) return false;
  return start.difference(now).inMinutes >
      studentCancelCutoffHours * 60;
}
