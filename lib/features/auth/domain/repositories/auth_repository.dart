import '../entities/app_user.dart';

/// Params for registration (collects role-specific fields up front).
class RegisterParams {
  const RegisterParams({
    required this.email,
    required this.password,
    required this.role,
    required this.name,
    this.phone,
    this.department,
    this.rollNumber,
    this.year,
    this.employeeId,
    this.designation,
    this.cabinNumber,
  });

  final String email;
  final String password;
  final UserRole role;
  final String name;
  final String? phone;
  final String? department;
  final String? rollNumber;
  final String? year;
  final String? employeeId;
  final String? designation;
  final String? cabinNumber;
}

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser?> currentUser();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp(RegisterParams params);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Future<void> updateProfile(AppUser user);
  Stream<AppUser?> watchProfile(String uid);
}
