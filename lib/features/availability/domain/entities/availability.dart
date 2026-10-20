import 'package:equatable/equatable.dart';

import '../../../../core/utils/time_utils.dart';

/// A faculty availability rule: either a weekly recurring window
/// ([dayOfWeek] 1 = Monday … 7 = Sunday) or a one-off window on
/// [specificDate] ("yyyy-MM-dd"). Times are "HH:mm" strings.
class AvailabilityRule extends Equatable {
  const AvailabilityRule({
    required this.id,
    required this.facultyId,
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    required this.endTime,
    required this.slotDuration,
    required this.isActive,
  });

  final String id;
  final String facultyId;
  final int? dayOfWeek;
  final String? specificDate;
  final String startTime;
  final String endTime;
  final int slotDuration;
  final bool isActive;

  int get startMinutes => parseHm(startTime);
  int get endMinutes => parseHm(endTime);

  bool get isOneOff => specificDate != null && specificDate!.isNotEmpty;

  /// Whether this rule contributes slots on [date].
  bool appliesTo(DateTime date) {
    if (!isActive) return false;
    if (isOneOff) return specificDate == dateKey(date);
    return dayOfWeek == date.weekday;
  }

  @override
  List<Object?> get props => [
        id,
        facultyId,
        dayOfWeek,
        specificDate,
        startTime,
        endTime,
        slotDuration,
        isActive,
      ];
}

/// A faculty-blocked date (leave, conference, holiday).
class BlockedDate extends Equatable {
  const BlockedDate({
    required this.id,
    required this.facultyId,
    required this.date,
    required this.reason,
  });

  final String id;
  final String facultyId;

  /// "yyyy-MM-dd".
  final String date;
  final String reason;

  @override
  List<Object?> get props => [id, facultyId, date, reason];
}
