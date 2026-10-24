import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../repositories/admin_repository.dart';

/// Result summary shown after seeding.
class SeedResult {
  const SeedResult({
    required this.faculty,
    required this.students,
    required this.rules,
    required this.appointments,
  });
  final int faculty;
  final int students;
  final int rules;
  final int appointments;

  @override
  String toString() =>
      '$faculty faculty, $students students, $rules availability rules, $appointments appointments';
}

/// Admin-only "Seed demo data": sample faculty, students, weekly
/// availability, a blocked date and appointments across every status, plus
/// welcome notifications. Writes appointments directly (seed bypasses the
/// booking transaction) and mirrors slot-locks for blocking ones so the
/// booking mutex stays consistent.
class SeedService {
  SeedService(this._db, this._admin);

  final FirebaseFirestore _db;
  final AdminRepository _admin;

  static const String markerPath = 'seed_meta/demo_v1';

  Future<SeedResult> seed() async {
    final marker = await _db.doc(markerPath).get();
    if (marker.exists) {
      throw Exception(
          'Demo data was already seeded. Delete seed_meta/demo_v1 to re-run.');
    }

    // 1. Departments from the static catalog (skip existing).
    final existing =
        await _db.collection('departments').get().then((s) => s.docs
            .map((d) => (d.data()['name'] as String? ?? '').toLowerCase())
            .toSet());
    for (final name in AppConstants.departments) {
      if (!existing.contains(name.toLowerCase())) {
        await _admin.addDepartment(name);
      }
    }

    // 2. Demo users (fixed credentials, documented on the Seed tab).
    final f1 = await _admin.createManagedUser(
      email: 'aarav.sharma@college.edu',
      password: 'faculty123',
      role: UserRole.faculty,
      name: 'Aarav Sharma',
      department: 'Computer Science',
      employeeId: 'FAC-1001',
      designation: 'Assistant Professor',
      cabinNumber: 'CS-204',
    );
    final f2 = await _admin.createManagedUser(
      email: 'meera.iyer@college.edu',
      password: 'faculty123',
      role: UserRole.faculty,
      name: 'Meera Iyer',
      department: 'Electrical Engineering',
      employeeId: 'FAC-1002',
      designation: 'Associate Professor',
      cabinNumber: 'EE-110',
    );
    final s1 = await _admin.createManagedUser(
      email: 'rohan@college.edu',
      password: 'student123',
      role: UserRole.student,
      name: 'Rohan Verma',
      department: 'Computer Science',
      rollNumber: 'CS23B001',
      year: '2nd',
    );
    final s2 = await _admin.createManagedUser(
      email: 'sana@college.edu',
      password: 'student123',
      role: UserRole.student,
      name: 'Sana Khan',
      department: 'Electrical Engineering',
      rollNumber: 'EE23B014',
      year: '2nd',
    );
    final s3 = await _admin.createManagedUser(
      email: 'dev@college.edu',
      password: 'student123',
      role: UserRole.student,
      name: 'Dev Patel',
      department: 'Computer Science',
      rollNumber: 'CS24B007',
      year: '1st',
    );

    // 3. Weekly availability Mon–Fri 10:00–12:00, 30 min slots.
    var ruleCount = 0;
    for (final f in [f1, f2]) {
      for (var weekday = DateTime.monday;
          weekday <= DateTime.friday;
          weekday++) {
        await _db.collection('availability').add({
          'facultyId': f.uid,
          'dayOfWeek': weekday,
          'startTime': '10:00',
          'endTime': '12:00',
          'slotDuration': 30,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ruleCount++;
      }
    }

    // 4. One blocked date next week for f1.
    final blockedDay = _nextWeekday(DateTime.monday, offsetWeeks: 1);
    await _db.collection('blockedDates').add({
      'facultyId': f1.uid,
      'date': dateKey(blockedDay),
      'reason': 'Conference travel',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 5. Appointments across statuses.
    final upcoming = _nextWeekday(DateTime.tuesday);
    final past = DateTime.now().subtract(const Duration(days: 3));
    var apptCount = 0;

    Future<void> addAppt({
      required AppUser student,
      required AppUser faculty,
      required DateTime day,
      required String start,
      required String end,
      required String purpose,
      required String status,
      String? rejectionReason,
      String? proposedDate,
      String? proposedStart,
      String? proposedEnd,
    }) async {
      final ref = _db.collection('appointments').doc();
      await ref.set({
        'studentId': student.uid,
        'facultyId': faculty.uid,
        'studentName': student.name,
        'facultyName': faculty.name,
        'date': dateKey(day),
        'startTime': start,
        'endTime': end,
        'purpose': purpose,
        'status': status,
        'rejectionReason': ?rejectionReason,
        'proposedDate': ?proposedDate,
        'proposedStartTime': ?proposedStart,
        'proposedEndTime': ?proposedEnd,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == 'pending' ||
          status == 'approved' ||
          status == 'rescheduled') {
        await _db
            .collection('slotLocks')
            .doc('${faculty.uid}_${dateKey(day)}_$start')
            .set({
          'facultyId': faculty.uid,
          'date': dateKey(day),
          'startTime': start,
          'appointmentId': ref.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      apptCount++;
    }

    await addAppt(
        student: s1, faculty: f1, day: upcoming, start: '10:00', end: '10:30', purpose: 'Doubts in Chapter 4', status: 'pending');
    await addAppt(
        student: s2, faculty: f1, day: upcoming, start: '10:30', end: '11:00', purpose: 'Project proposal review', status: 'approved');
    await addAppt(
        student: s3, faculty: f2, day: upcoming, start: '11:00', end: '11:30', purpose: 'Lab report discussion', status: 'approved');
    await addAppt(
        student: s1, faculty: f2, day: past, start: '10:00', end: '10:30', purpose: 'Circuit analysis help', status: 'completed');
    await addAppt(
        student: s2, faculty: f2, day: past, start: '10:30', end: '11:00', purpose: 'Missed lecture topics', status: 'no_show');
    await addAppt(
        student: s3, faculty: f1, day: past, start: '11:00', end: '11:30', purpose: 'Internship guidance', status: 'cancelled');
    await addAppt(
        student: s1, faculty: f2, day: past, start: '11:00', end: '11:30', purpose: 'Quiz preparation', status: 'rejected', rejectionReason: 'Out of station that week');
    await addAppt(
        student: s2, faculty: f1, day: upcoming, start: '11:00', end: '11:30', purpose: 'Seminar feedback', status: 'rescheduled', proposedDate: dateKey(upcoming.add(const Duration(days: 1))), proposedStart: '10:00', proposedEnd: '10:30');

    // 6. Welcome notifications.
    for (final u in [f1, f2, s1, s2, s3]) {
      await _db.collection('notifications').add({
        'userId': u.uid,
        'title': 'Welcome to Faculty Pre-Booking',
        'body': 'Demo data is ready. Explore your dashboard!',
        'type': 'info',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.doc(markerPath).set({
      'seededAt': FieldValue.serverTimestamp(),
      'version': 1,
    });

    return SeedResult(
        faculty: 2, students: 3, rules: ruleCount, appointments: apptCount);
  }

  /// Next occurrence of [weekday], optionally pushed [offsetWeeks] ahead.
  DateTime _nextWeekday(int weekday, {int offsetWeeks = 0}) {
    var d = DateTime.now().add(Duration(days: 1 + offsetWeeks * 7));
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}
