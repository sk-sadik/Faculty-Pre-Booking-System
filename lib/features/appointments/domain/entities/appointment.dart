import 'package:equatable/equatable.dart';

import '../../../../core/utils/time_utils.dart';

/// Appointment lifecycle status. Stored in Firestore with [value].
enum AppointmentStatus {
  pending,
  approved,
  rejected,
  rescheduled,
  cancelled,
  completed,
  noShow,
}

extension AppointmentStatusX on AppointmentStatus {
  String get value =>
      this == AppointmentStatus.noShow ? 'no_show' : name;

  static AppointmentStatus fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'approved':
        return AppointmentStatus.approved;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'rescheduled':
        return AppointmentStatus.rescheduled;
      case 'cancelled':
      case 'canceled':
        return AppointmentStatus.cancelled;
      case 'completed':
        return AppointmentStatus.completed;
      case 'no_show':
      case 'no-show':
      case 'noshow':
        return AppointmentStatus.noShow;
      case 'pending':
      default:
        return AppointmentStatus.pending;
    }
  }
}

/// A booked meeting between a student and a faculty member.
/// Dates are "yyyy-MM-dd" keys, times are "HH:mm" strings so day-scoped
/// Firestore queries (`facultyId + date`) work without composite pain.
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.studentId,
    required this.facultyId,
    required this.studentName,
    required this.facultyName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.purpose,
    this.note,
    required this.status,
    this.rejectionReason,
    this.proposedDate,
    this.proposedStartTime,
    this.proposedEndTime,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String facultyId;
  final String studentName;
  final String facultyName;
  final String date;
  final String startTime;
  final String endTime;
  final String purpose;
  final String? note;
  final AppointmentStatus status;
  final String? rejectionReason;
  final String? proposedDate;
  final String? proposedStartTime;
  final String? proposedEndTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get startMinutes => parseHm(startTime);
  int get endMinutes => parseHm(endTime);

  /// True while the appointment still occupies its slot.
  bool get isBlocking =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.approved ||
      status == AppointmentStatus.rescheduled;

  bool get isTerminal =>
      status == AppointmentStatus.rejected ||
      status == AppointmentStatus.cancelled ||
      status == AppointmentStatus.completed ||
      status == AppointmentStatus.noShow;

  @override
  List<Object?> get props => [
        id,
        studentId,
        facultyId,
        studentName,
        facultyName,
        date,
        startTime,
        endTime,
        purpose,
        note,
        status,
        rejectionReason,
        proposedDate,
        proposedStartTime,
        proposedEndTime,
      ];
}
