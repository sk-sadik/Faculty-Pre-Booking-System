import 'package:faculty_pre_booking/features/appointments/domain/entities/appointment.dart';
import 'package:faculty_pre_booking/features/appointments/domain/slot_generator.dart';
import 'package:faculty_pre_booking/features/availability/domain/entities/availability.dart';
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

AvailabilityRule _rule({
  int? dayOfWeek = 2, // Tuesday; 2026-10-20 is a Tuesday
  String start = '09:00',
  String end = '11:00',
  int duration = 30,
}) =>
    AvailabilityRule(
      id: 'r',
      facultyId: 'f1',
      dayOfWeek: dayOfWeek,
      startTime: start,
      endTime: end,
      slotDuration: duration,
      isActive: true,
    );

void main() {
  const gen = SlotGenerator();
  // 2026-10-20 is a Tuesday.
  final tuesday = DateTime(2026, 10, 20);

  group('SlotGenerator', () {
    test('expands a window into slots', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: const [],
        maxPerDay: 8,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 19, 12),
      );
      expect(slots.map((s) => s.label).toList(), [
        '09:00 – 09:30',
        '09:30 – 10:00',
        '10:00 – 10:30',
        '10:30 – 11:00',
      ]);
    });

    test('blocked date yields no slots', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [
          BlockedDate(
              id: 'b', facultyId: 'f1', date: '2026-10-20', reason: 'Leave')
        ],
        existing: const [],
        maxPerDay: 8,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 19, 12),
      );
      expect(slots, isEmpty);
    });

    test('existing appointments remove overlapping slots', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: [_appt(start: '09:30', end: '10:00')],
        maxPerDay: 8,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 19, 12),
      );
      expect(slots.map((s) => s.label).toList(),
          ['09:00 – 09:30', '10:00 – 10:30', '10:30 – 11:00']);
    });

    test('buffer widens occupied ranges', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: [_appt(start: '10:00', end: '10:30')],
        maxPerDay: 8,
        bufferMinutes: 30,
        now: DateTime(2026, 10, 19, 12),
      );
      // Occupied zone is 09:30–11:00 (10:00–10:30 ± 30min buffer), so only
      // the first slot survives: 10:30–11:00 would start inside the buffer.
      expect(
          slots.map((s) => s.label).toList(), ['09:00 – 09:30']);
    });

    test('full day (maxPerDay reached) yields no slots', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: [
          _appt(id: 'a1', start: '09:00', end: '09:30'),
          _appt(id: 'a2', start: '09:30', end: '10:00'),
        ],
        maxPerDay: 2,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 19, 12),
      );
      expect(slots, isEmpty);
    });

    test('past times are skipped for today', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: const [],
        maxPerDay: 8,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 20, 10, 5),
      );
      expect(slots.map((s) => s.label).toList(), ['10:30 – 11:00']);
    });

    test('cancelled appointments do not block slots', () {
      final slots = gen.generate(
        date: tuesday,
        rules: [_rule()],
        blocked: const [],
        existing: [
          _appt(start: '09:30', end: '10:00', status: AppointmentStatus.cancelled)
        ],
        maxPerDay: 8,
        bufferMinutes: 0,
        now: DateTime(2026, 10, 19, 12),
      );
      expect(slots, hasLength(4));
    });
  });
}
