import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/app_user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/repositories/users_repository.dart';

/// Firestore implementation backed by `users`.
class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users');

  List<AppUser> _decode(QuerySnapshot<Map<String, dynamic>> s) {
    final list =
        s.docs.map((d) => AppUserModel.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _col.doc(uid).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      return AppUserModel.fromMap(d.id, d.data()!);
    });
  }

  @override
  Stream<List<AppUser>> watchFaculty() => watchByRole(UserRole.faculty);

  @override
  Stream<List<AppUser>> watchByRole(UserRole role) {
    return _col.where('role', isEqualTo: role.value).snapshots().map(_decode);
  }

  @override
  Future<void> updateFcmToken(String uid, String? token) {
    return _col.doc(uid).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setAvailableNow(String uid, bool value) {
    return _col.doc(uid).update({
      'isAvailableNow': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateBookingSettings(
    String uid, {
    required int maxPerDay,
    required int bufferMinutes,
  }) {
    return _col.doc(uid).update({
      'maxPerDay': maxPerDay,
      'bufferMinutes': bufferMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteUserDoc(String uid) => _col.doc(uid).delete();
}
