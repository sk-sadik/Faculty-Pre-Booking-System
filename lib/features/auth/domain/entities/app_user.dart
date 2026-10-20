/// Domain entity for an authenticated user.
enum UserRole { student, faculty, admin }

extension UserRoleX on UserRole {
  String get value => name;

  static UserRole fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.department,
    this.photoUrl,
    // Student-specific
    this.rollNumber,
    this.year,
    // Faculty-specific
    this.employeeId,
    this.designation,
    this.cabinNumber,
    // Push + faculty booking settings (Phase B)
    this.fcmToken,
    this.isAvailableNow,
    this.maxPerDay,
    this.bufferMinutes,
    this.createdAt,
  });

  final String uid;
  final String email;
  final UserRole role;
  final String name;
  final String? phone;
  final String? department;
  final String? photoUrl;
  final String? rollNumber;
  final String? year;
  final String? employeeId;
  final String? designation;
  final String? cabinNumber;
  final String? fcmToken;
  final bool? isAvailableNow;
  final int? maxPerDay;
  final int? bufferMinutes;
  final DateTime? createdAt;

  /// Effective max bookings per day (faculty default 8).
  int get effectiveMaxPerDay => maxPerDay ?? 8;

  /// Effective buffer between meetings in minutes (faculty default 10).
  int get effectiveBufferMinutes => bufferMinutes ?? 10;

  AppUser copyWith({
    String? name,
    String? phone,
    String? department,
    String? photoUrl,
    String? rollNumber,
    String? year,
    String? employeeId,
    String? designation,
    String? cabinNumber,
    String? fcmToken,
    bool? isAvailableNow,
    int? maxPerDay,
    int? bufferMinutes,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      role: role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      rollNumber: rollNumber ?? this.rollNumber,
      year: year ?? this.year,
      employeeId: employeeId ?? this.employeeId,
      designation: designation ?? this.designation,
      cabinNumber: cabinNumber ?? this.cabinNumber,
      fcmToken: fcmToken ?? this.fcmToken,
      isAvailableNow: isAvailableNow ?? this.isAvailableNow,
      maxPerDay: maxPerDay ?? this.maxPerDay,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      createdAt: createdAt,
    );
  }
}
