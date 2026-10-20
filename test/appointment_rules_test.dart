import 'package:faculty_pre_booking/features/appointments/domain/appointment_rules.dart';
import 'package:faculty_pre_booking/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appt({
  String id = 'a',
  String date = '2026-10-20',
  String start = '10:00',
  String end = '10:30',
  AppointmentStatus status = AppointmentStatus.approved,
}) =>
    Appointment(
      id: id,
      studentId: 's1',
      facultyId: 'f1',
      studentName: 'Stu',
      facultyName: 'Fac',
      date: date,
      startTime: start,
      endTime: end,
      purpose: 'Doubt',
      status: status,
    );

void main() {
  group('status transitions', () {
    test('pending → approved/rejected/cancelled only', () {
      expect(canTransition(AppointmentStatus.pending, AppointmentStatus.approved),
          isTrue);
      expect(canTransition(AppointmentStatus.pending, AppointmentStatus.rejected),
          isTrue);
      expect(canTransition(AppointmentStatus.pending, AppointmentStatus.cancelled),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.pending, AppointmentStatus.completed),
          isFalse);
      expect(
          canTransition(
              AppointmentStatus.pending, AppointmentStatus.rescheduled),
          isFalse);
    });

    test('approved → rescheduled/completed/cancelled/noShow only', () {
      expect(
          canTransition(
              AppointmentStatus.approved, AppointmentStatus.rescheduled),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.approved, AppointmentStatus.completed),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.approved, AppointmentStatus.cancelled),
          isTrue);
      expect(
          canTransition(AppointmentStatus.approved, AppointmentStatus.noShow),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.approved, AppointmentStatus.pending),
          isFalse);
      expect(
          canTransition(
              AppointmentStatus.approved, AppointmentStatus.rejected),
          isFalse);
    });

    test('rescheduled → approved/cancelled only', () {
      expect(
          canTransition(
              AppointmentStatus.rescheduled, AppointmentStatus.approved),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.rescheduled, AppointmentStatus.cancelled),
          isTrue);
      expect(
          canTransition(
              AppointmentStatus.rescheduled, AppointmentStatus.completed),
          isFalse);
    });

    test('terminal states allow nothing', () {
      for (final s in [
        AppointmentStatus.rejected,
        AppointmentStatus.cancelled,
        AppointmentStatus.completed,
        AppointmentStatus.noShow,
      ]) {
        for (final t in AppointmentStatus.values) {
          expect(canTransition(s, t), isFalse, reason: '${s.value} → ${t.value}');
        }
      }
    });

    test('requireTransition throws a clear error', () {
      expect(
          () => requireTransition(
              AppointmentStatus.pending, AppointmentStatus.completed),
          throwsA(isA<AppointmentRuleViolation>()));
    });
  });

  group('overlap detection', () {
    test('touching edges do not overlap', () {
      expect(timesOverlap(600, 630, 630, 660), isFalse);
      expect(timesOverlap(600, 631, 630, 660), isTrue);
    });

    test('student double-booking is detected, terminal ignored', () {
      final existing = [
        _appt(),
        _appt(
            id: 'x',
            start: '14:00',
            end: '14:30',
            status: AppointmentStatus.cancelled),
      ];
      expect(
          studentHasOverlap(
              existing: existing,
              date: '2026-10-20',
              startMinutes: 615,
              endMinutes: 645),
          isTrue);
      expect(
          studentHasOverlap(
              existing: existing,
              date: '2026-10-20',
              startMinutes: 840,
              endMinutes: 870),
          isFalse);
      expect(
          studentHasOverlap(
              existing: existing,
              date: '2026-10-21',
              startMinutes: 615,
              endMinutes: 645),
          isFalse);
    });
  });

  group('student cancel cutoff', () {
    test('allowed more than 2h before, blocked inside', () {
      expect(
          canStudentCancel(
              date: '2026-10-20',
              startTime: '10:00',
              now: DateTime(2026, 10, 20, 7, 59)),
          isTrue);
      expect(
          canStudentCancel(
              date: '2026-10-20',
              startTime: '10:00',
              now: DateTime(2026, 10, 20, 8, 0)),
          isFalse);
      expect(
          canStudentCancel(
              date: '2026-10-20',
              startTime: '10:00',
              now: DateTime(2026, 10, 20, 11, 0)),
          isFalse);
    });
  });
}
