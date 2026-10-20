import '../entities/appointment.dart';

/// Payload for the notification written alongside a status change.
class StatusNotification {
  const StatusNotification({
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
  });

  final String userId;
  final String title;
  final String body;
  final String type;
}

abstract class AppointmentRepository {
  Stream<List<Appointment>> watchStudentAppointments(String studentId);
  Stream<List<Appointment>> watchFacultyAppointments(String facultyId);
  Stream<List<Appointment>> watchFacultyDay(String facultyId, String dateKey);

  /// Admin analytics: most recently created appointments (bounded).
  Stream<List<Appointment>> watchRecent({int limit = 500});
  Stream<Appointment?> watchAppointment(String appointmentId);

  /// Books a new pending appointment inside a Firestore transaction that
  /// rejects faculty-slot clashes, same-student overlaps, and full days.
  /// Returns the new document id.
  Future<String> bookAppointment({
    required String studentId,
    required String studentName,
    required String facultyId,
    required String facultyName,
    required String date,
    required String startTime,
    required String endTime,
    required String purpose,
    String? note,
  });

  /// Generic transition with [requireTransition] validation + notification.
  Future<void> updateStatus({
    required String appointmentId,
    required AppointmentStatus to,
    String? rejectionReason,
    Map<String, dynamic>? extra,
    StatusNotification? notification,
  });

  /// Faculty proposes a new time: approved → rescheduled + student notified.
  Future<void> proposeReschedule({
    required String appointmentId,
    required String proposedDate,
    required String proposedStartTime,
    required String proposedEndTime,
  });

  /// Student answers a proposal: rescheduled → approved (accept) with the
  /// new time adopted, or → cancelled (decline, bypasses cancel cutoff
  /// because the faculty initiated the change).
  Future<void> respondReschedule({
    required String appointmentId,
    required bool accept,
  });

  /// Student cancel with the 2-hour cutoff enforced.
  Future<void> cancelAsStudent({
    required String appointmentId,
    required DateTime now,
  });
}
