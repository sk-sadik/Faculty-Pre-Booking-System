import '../../../auth/domain/entities/app_user.dart';

/// Directory + settings access over `users`. Auth (sign-in/up, session)
/// stays in [AuthRepository]; this covers everything else.
abstract class UsersRepository {
  Stream<AppUser?> watchUser(String uid);
  Stream<List<AppUser>> watchFaculty();
  Stream<List<AppUser>> watchByRole(UserRole role);

  Future<void> updateFcmToken(String uid, String? token);
  Future<void> setAvailableNow(String uid, bool value);
  Future<void> updateBookingSettings(
    String uid, {
    required int maxPerDay,
    required int bufferMinutes,
  });

  /// Admin: removes the Firestore profile doc. (Firebase Auth deletion
  /// needs the Admin SDK / console — documented in README Phase F.)
  Future<void> deleteUserDoc(String uid);
}
