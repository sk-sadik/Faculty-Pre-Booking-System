import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';

/// Firestore serialization for users/{uid}.
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    required super.role,
    required super.name,
    super.phone,
    super.department,
    super.photoUrl,
    super.rollNumber,
    super.year,
    super.employeeId,
    super.designation,
    super.cabinNumber,
    super.fcmToken,
    super.isAvailableNow,
    super.maxPerDay,
    super.bufferMinutes,
    super.createdAt,
  });

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();
    if (raw is String) created = DateTime.tryParse(raw);
    // Accept legacy/alternate keys (rollNo, cabin) on read; writes use the
    // canonical names below so login/signup behavior is unchanged.
    return AppUserModel(
      uid: uid,
      email: (map['email'] as String? ?? '').trim(),
      role: UserRoleX.fromString(map['role'] as String?),
      name: (map['name'] as String? ?? '').trim(),
      phone: map['phone'] as String?,
      department: map['department'] as String?,
      photoUrl: map['photoUrl'] as String?,
      rollNumber: (map['rollNumber'] ?? map['rollNo']) as String?,
      year: map['year'] as String?,
      employeeId: map['employeeId'] as String?,
      designation: map['designation'] as String?,
      cabinNumber: (map['cabinNumber'] ?? map['cabin']) as String?,
      fcmToken: map['fcmToken'] as String?,
      isAvailableNow: map['isAvailableNow'] as bool? ?? false,
      maxPerDay: (map['maxPerDay'] as num?)?.toInt() ?? 8,
      bufferMinutes: (map['bufferMinutes'] as num?)?.toInt() ?? 10,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.value,
      'name': name,
      if (phone != null) 'phone': phone,
      if (department != null) 'department': department,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (rollNumber != null) 'rollNumber': rollNumber,
      if (year != null) 'year': year,
      if (employeeId != null) 'employeeId': employeeId,
      if (designation != null) 'designation': designation,
      if (cabinNumber != null) 'cabinNumber': cabinNumber,
      if (fcmToken != null) 'fcmToken': fcmToken,
      // Booking settings always materialize for faculty so slot generation
      // and the booking transaction have deterministic defaults.
      if (role == UserRole.faculty) ...{
        'isAvailableNow': isAvailableNow ?? false,
        'maxPerDay': maxPerDay ?? 8,
        'bufferMinutes': bufferMinutes ?? 10,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppUserModel.fromEntity(AppUser e) => AppUserModel(
        uid: e.uid,
        email: e.email,
        role: e.role,
        name: e.name,
        phone: e.phone,
        department: e.department,
        photoUrl: e.photoUrl,
        rollNumber: e.rollNumber,
        year: e.year,
        employeeId: e.employeeId,
        designation: e.designation,
        cabinNumber: e.cabinNumber,
        fcmToken: e.fcmToken,
        isAvailableNow: e.isAvailableNow,
        maxPerDay: e.maxPerDay,
        bufferMinutes: e.bufferMinutes,
        createdAt: e.createdAt,
      );
}
