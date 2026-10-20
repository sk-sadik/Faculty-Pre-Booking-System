import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment.dart';

/// Firestore serialization for `appointments/{id}`.
class AppointmentModel extends Appointment {
  const AppointmentModel({
    required super.id,
    required super.studentId,
    required super.facultyId,
    required super.studentName,
    required super.facultyName,
    required super.date,
    required super.startTime,
    required super.endTime,
    required super.purpose,
    super.note,
    required super.status,
    super.rejectionReason,
    super.proposedDate,
    super.proposedStartTime,
    super.proposedEndTime,
    super.createdAt,
    super.updatedAt,
  });

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? stamp(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return AppointmentModel(
      id: id,
      studentId: (map['studentId'] as String? ?? ''),
      facultyId: (map['facultyId'] as String? ?? ''),
      studentName: (map['studentName'] as String? ?? ''),
      facultyName: (map['facultyName'] as String? ?? ''),
      date: (map['date'] as String? ?? ''),
      startTime: (map['startTime'] as String? ?? ''),
      endTime: (map['endTime'] as String? ?? ''),
      purpose: (map['purpose'] as String? ?? ''),
      note: map['note'] as String?,
      status: AppointmentStatusX.fromString(map['status'] as String?),
      rejectionReason: map['rejectionReason'] as String?,
      proposedDate: map['proposedDate'] as String?,
      proposedStartTime: map['proposedStartTime'] as String?,
      proposedEndTime: map['proposedEndTime'] as String?,
      createdAt: stamp(map['createdAt']),
      updatedAt: stamp(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMapForCreate() => {
        'studentId': studentId,
        'facultyId': facultyId,
        'studentName': studentName,
        'facultyName': facultyName,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'purpose': purpose,
        if (note != null && note!.isNotEmpty) 'note': note,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
