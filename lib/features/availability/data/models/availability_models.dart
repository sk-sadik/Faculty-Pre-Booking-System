import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/availability.dart';

/// Firestore serialization for `availability/{id}` and `blockedDates/{id}`.
class AvailabilityModel extends AvailabilityRule {
  const AvailabilityModel({
    required super.id,
    required super.facultyId,
    super.dayOfWeek,
    super.specificDate,
    required super.startTime,
    required super.endTime,
    required super.slotDuration,
    required super.isActive,
  });

  factory AvailabilityModel.fromMap(String id, Map<String, dynamic> map) {
    return AvailabilityModel(
      id: id,
      facultyId: (map['facultyId'] as String? ?? ''),
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt(),
      specificDate: map['specificDate'] as String?,
      startTime: (map['startTime'] as String? ?? '09:00'),
      endTime: (map['endTime'] as String? ?? '10:00'),
      slotDuration: (map['slotDuration'] as num?)?.toInt() ?? 30,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class BlockedDateModel extends BlockedDate {
  const BlockedDateModel({
    required super.id,
    required super.facultyId,
    required super.date,
    required super.reason,
  });

  factory BlockedDateModel.fromMap(String id, Map<String, dynamic> map) {
    return BlockedDateModel(
      id: id,
      facultyId: (map['facultyId'] as String? ?? ''),
      date: (map['date'] as String? ?? ''),
      reason: (map['reason'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'facultyId': facultyId,
        'date': date,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
