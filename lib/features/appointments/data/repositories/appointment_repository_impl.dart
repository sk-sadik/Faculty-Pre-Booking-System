import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/time_utils.dart';
import '../../domain/appointment_rules.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../models/appointment_model.dart';

/// Firestore implementation. Overlap / capacity pre-checks run as regular
/// queries; the commit itself (slot-lock + appointment + notification) runs
/// inside a transaction so two students cannot take the same slot: the
/// deterministic `slotLocks/{facultyId_date_startTime}` doc can only be
/// created once, and concurrent same-slot bookings contend on it.
class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('appointments');
  CollectionReference<Map<String, dynamic>> get _notifs =>
      _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _locks =>
      _db.collection('slotLocks');

  static const List<String> _blockingStatuses = [
    'pending',
    'approved',
    'rescheduled'
  ];

  /// Deterministic mutual-exclusion key for one faculty slot.
  String _lockId(String facultyId, String date, String startTime) =>
      '${facultyId}_${date}_$startTime';

  List<Appointment> _decode(QuerySnapshot<Map<String, dynamic>> s) {
    final list =
        s.docs.map((d) => AppointmentModel.fromMap(d.id, d.data())).toList();
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Stream<List<Appointment>> watchStudentAppointments(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_decode);
  }

  @override
  Stream<List<Appointment>> watchFacultyAppointments(String facultyId) {
    return _col
        .where('facultyId', isEqualTo: facultyId)
        .snapshots()
        .map(_decode);
  }

  @override
  Stream<List<Appointment>> watchFacultyDay(
      String facultyId, String dateKey) {
    return _col
        .where('facultyId', isEqualTo: facultyId)
        .where('date', isEqualTo: dateKey)
        .snapshots()
        .map(_decode);
  }

  @override
  Stream<Appointment?> watchAppointment(String appointmentId) {
    return _col.doc(appointmentId).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      return AppointmentModel.fromMap(d.id, d.data()!);
    });
  }

  @override
  Stream<List<Appointment>> watchRecent({int limit = 500}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_decode);
  }

  @override
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
  }) async {
    final start = parseHm(startTime);
    final end = parseHm(endTime);
    if (end <= start) {
      throw const BookingConflict('End time must be after start time.');
    }

    // 1. Faculty slot clash (regular query; atomic guard below).
    final facSnap = await _col
        .where('facultyId', isEqualTo: facultyId)
        .where('date', isEqualTo: date)
        .where('status', whereIn: _blockingStatuses)
        .get();
    for (final d in facSnap.docs) {
      final m = AppointmentModel.fromMap(d.id, d.data());
      if (timesOverlap(start, end, m.startMinutes, m.endMinutes)) {
        throw const BookingConflict(
            'That slot was just taken. Please pick another time.');
      }
    }

    // 2. Same-student overlap (any faculty, same day).
    final stuSnap = await _col
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: date)
        .where('status', whereIn: _blockingStatuses)
        .get();
    for (final d in stuSnap.docs) {
      final m = AppointmentModel.fromMap(d.id, d.data());
      if (timesOverlap(start, end, m.startMinutes, m.endMinutes)) {
        throw const BookingConflict(
            'You already have an appointment overlapping this time.');
      }
    }

    // 3. Faculty day capacity.
    final facultySnap = await _users.doc(facultyId).get();
    final maxPerDay =
        (facultySnap.data()?['maxPerDay'] as num?)?.toInt() ?? 8;
    if (facSnap.docs.length >= maxPerDay) {
      throw const BookingConflict(
          'This faculty is fully booked for the day.');
    }

    // 4. Atomic commit guarded by the slot-lock doc.
    final newRef = _col.doc();
    final lockRef = _locks.doc(_lockId(facultyId, date, startTime));
    await _db.runTransaction((tx) async {
      final lock = await tx.get(lockRef);
      if (lock.exists) {
        throw const BookingConflict(
            'That slot was just taken. Please pick another time.');
      }
      tx.set(lockRef, {
        'facultyId': facultyId,
        'date': date,
        'startTime': startTime,
        'appointmentId': newRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
          newRef,
          AppointmentModel(
            id: newRef.id,
            studentId: studentId,
            facultyId: facultyId,
            studentName: studentName,
            facultyName: facultyName,
            date: date,
            startTime: startTime,
            endTime: endTime,
            purpose: purpose,
            note: note,
            status: AppointmentStatus.pending,
          ).toMapForCreate());
      tx.set(_notifs.doc(), {
        'userId': facultyId,
        'title': 'New booking request',
        'body': '$studentName requested $date at $startTime.',
        'type': 'request',
        'appointmentId': newRef.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return newRef.id;
  }

  @override
  Future<void> updateStatus({
    required String appointmentId,
    required AppointmentStatus to,
    String? rejectionReason,
    Map<String, dynamic>? extra,
    StatusNotification? notification,
  }) async {
    final ref = _col.doc(appointmentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) {
        throw const BookingConflict('Appointment no longer exists.');
      }
      final current = AppointmentModel.fromMap(snap.id, snap.data()!);
      requireTransition(current.status, to);
      if (to == AppointmentStatus.rejected &&
          (rejectionReason == null || rejectionReason.trim().isEmpty)) {
        throw const BookingConflict(
            'A reason is required when rejecting a request.');
      }
      tx.update(ref, {
        'status': to.value,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (extra != null) ...extra,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Slot-lock maintenance: a reschedule-accept moves the lock to the
      // new slot (contending atomically); any other terminal move frees it.
      final newDate = extra?['date'] as String?;
      final newStart = extra?['startTime'] as String?;
      final oldLock = _locks.doc(
          _lockId(current.facultyId, current.date, current.startTime));
      if (newDate != null && newStart != null) {
        final newLock =
            _locks.doc(_lockId(current.facultyId, newDate, newStart));
        final taken = await tx.get(newLock);
        if (taken.exists) {
          throw const BookingConflict(
              'The proposed time was just taken. Please propose another.');
        }
        tx.set(newLock, {
          'facultyId': current.facultyId,
          'date': newDate,
          'startTime': newStart,
          'appointmentId': appointmentId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.delete(oldLock);
      } else if (to == AppointmentStatus.rejected ||
          to == AppointmentStatus.cancelled ||
          to == AppointmentStatus.completed ||
          to == AppointmentStatus.noShow) {
        tx.delete(oldLock);
      }

      if (notification != null) {
        tx.set(_notifs.doc(), {
          'userId': notification.userId,
          'title': notification.title,
          'body': notification.body,
          'type': notification.type,
          'appointmentId': appointmentId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> proposeReschedule({
    required String appointmentId,
    required String proposedDate,
    required String proposedStartTime,
    required String proposedEndTime,
  }) async {
    final ref = _col.doc(appointmentId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const BookingConflict('Appointment no longer exists.');
    }
    final current = AppointmentModel.fromMap(snap.id, snap.data()!);
    final pStart = parseHm(proposedStartTime);
    final pEnd = parseHm(proposedEndTime);
    if (pEnd <= pStart) {
      throw const BookingConflict('End time must be after start time.');
    }
    // Guard: the proposed time must not overlap another blocking meeting
    // of the same faculty (the UI only offers free slots; this covers
    // races and stale data).
    final clash = await _col
        .where('facultyId', isEqualTo: current.facultyId)
        .where('date', isEqualTo: proposedDate)
        .where('status', whereIn: _blockingStatuses)
        .get();
    for (final d in clash.docs) {
      if (d.id == appointmentId) continue;
      final m = AppointmentModel.fromMap(d.id, d.data());
      if (timesOverlap(pStart, pEnd, m.startMinutes, m.endMinutes)) {
        throw const BookingConflict(
            'The proposed time overlaps an existing meeting.');
      }
    }
    await updateStatus(
      appointmentId: appointmentId,
      to: AppointmentStatus.rescheduled,
      extra: {
        'proposedDate': proposedDate,
        'proposedStartTime': proposedStartTime,
        'proposedEndTime': proposedEndTime,
      },
      notification: StatusNotification(
        userId: current.studentId,
        title: 'New time proposed',
        body:
            '${current.facultyName} proposed $proposedDate at $proposedStartTime.',
        type: 'rescheduled',
      ),
    );
  }

  @override
  Future<void> respondReschedule({
    required String appointmentId,
    required bool accept,
  }) async {
    final ref = _col.doc(appointmentId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const BookingConflict('Appointment no longer exists.');
    }
    final current = AppointmentModel.fromMap(snap.id, snap.data()!);
    if (accept) {
      await updateStatus(
        appointmentId: appointmentId,
        to: AppointmentStatus.approved,
        extra: {
          // Adopt the faculty-proposed time as the meeting time.
          'date': current.proposedDate ?? current.date,
          'startTime': current.proposedStartTime ?? current.startTime,
          'endTime': current.proposedEndTime ?? current.endTime,
          'proposedDate': FieldValue.delete(),
          'proposedStartTime': FieldValue.delete(),
          'proposedEndTime': FieldValue.delete(),
        },
        notification: StatusNotification(
          userId: current.facultyId,
          title: 'Reschedule accepted',
          body: '${current.studentName} accepted the proposed time.',
          type: 'approved',
        ),
      );
    } else {
      await updateStatus(
        appointmentId: appointmentId,
        to: AppointmentStatus.cancelled,
        notification: StatusNotification(
          userId: current.facultyId,
          title: 'Reschedule declined',
          body:
              '${current.studentName} declined the proposed time. The request was cancelled.',
          type: 'cancelled',
        ),
      );
    }
  }

  @override
  Future<void> cancelAsStudent({
    required String appointmentId,
    required DateTime now,
  }) async {
    final ref = _col.doc(appointmentId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const BookingConflict('Appointment no longer exists.');
    }
    final current = AppointmentModel.fromMap(snap.id, snap.data()!);
    if (!canStudentCancel(
        date: current.date, startTime: current.startTime, now: now)) {
      throw const BookingConflict(
          'Cancellation is only allowed more than 2 hours before the meeting.');
    }
    await updateStatus(
      appointmentId: appointmentId,
      to: AppointmentStatus.cancelled,
      notification: StatusNotification(
        userId: current.facultyId,
        title: 'Appointment cancelled',
        body:
            '${current.studentName} cancelled the meeting on ${current.date} at ${current.startTime}.',
        type: 'cancelled',
      ),
    );
  }
}
