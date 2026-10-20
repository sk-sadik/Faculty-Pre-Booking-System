import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/appointment_repository_impl.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';

final appointmentRepositoryProvider =
    Provider<AppointmentRepository>((ref) {
  return AppointmentRepositoryImpl(ref.watch(firestoreProvider));
});

/// All appointments of one student (client filters by status tab).
final studentAppointmentsProvider = StreamProvider.autoDispose
    .family<List<Appointment>, String>((ref, studentId) {
  return ref
      .watch(appointmentRepositoryProvider)
      .watchStudentAppointments(studentId);
});

/// All appointments of one faculty member.
final facultyAppointmentsProvider = StreamProvider.autoDispose
    .family<List<Appointment>, String>((ref, facultyId) {
  return ref
      .watch(appointmentRepositoryProvider)
      .watchFacultyAppointments(facultyId);
});

/// One faculty's appointments on one day ("yyyy-MM-dd") — feeds slot
/// generation and the faculty calendar.
final facultyDayAppointmentsProvider = StreamProvider.autoDispose
    .family<List<Appointment>, ({String facultyId, String dateKey})>(
        (ref, args) {
  return ref
      .watch(appointmentRepositoryProvider)
      .watchFacultyDay(args.facultyId, args.dateKey);
});

/// Single appointment detail (status tracking screen).
final appointmentDetailProvider = StreamProvider.autoDispose
    .family<Appointment?, String>((ref, appointmentId) {
  return ref
      .watch(appointmentRepositoryProvider)
      .watchAppointment(appointmentId);
});

/// Pending requests inbox for a faculty member.
final facultyPendingRequestsProvider = StreamProvider.autoDispose
    .family<List<Appointment>, String>((ref, facultyId) {
  return ref
      .watch(appointmentRepositoryProvider)
      .watchFacultyAppointments(facultyId)
      .map((list) => list
          .where((a) => a.status == AppointmentStatus.pending)
          .toList());
});
