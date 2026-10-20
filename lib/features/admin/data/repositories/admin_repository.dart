import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../firebase_options.dart';
import '../../../auth/data/models/app_user_model.dart';
import '../../../auth/domain/entities/app_user.dart';

/// Admin operations: managed user creation, departments, dashboard helpers.
///
/// Managed users are created through a throwaway secondary [FirebaseApp] so
/// the admin's own session is never disturbed (client-side creation on the
/// default Auth instance would sign the admin out).
class AdminRepository {
  AdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _departments =>
      _db.collection('departments');

  Future<AppUser> createManagedUser({
    required String email,
    required String password,
    required UserRole role,
    required String name,
    String? department,
    String? phone,
    String? rollNumber,
    String? year,
    String? employeeId,
    String? designation,
    String? cabinNumber,
  }) async {
    FirebaseApp? secondary;
    try {
      secondary = await Firebase.initializeApp(
        name: 'admin-secondary-${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final fbUser = cred.user;
      if (fbUser == null) {
        throw Exception('Account creation failed. Please try again.');
      }
      await fbUser.updateDisplayName(name.trim());
      final model = AppUserModel(
        uid: fbUser.uid,
        email: email.trim(),
        role: role,
        name: name.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
        department: department,
        rollNumber: rollNumber?.trim().isEmpty == true
            ? null
            : rollNumber?.trim(),
        year: year,
        employeeId: employeeId?.trim().isEmpty == true
            ? null
            : employeeId?.trim(),
        designation: designation?.trim().isEmpty == true
            ? null
            : designation?.trim(),
        cabinNumber: cabinNumber?.trim().isEmpty == true
            ? null
            : cabinNumber?.trim(),
      );
      await _users.doc(fbUser.uid).set(model.toMap());
      await auth.signOut();
      final doc = await _users.doc(fbUser.uid).get();
      return AppUserModel.fromMap(fbUser.uid, doc.data()!);
    } finally {
      await secondary?.delete();
    }
  }

  Stream<List<String>> watchDepartmentNames() {
    return _departments.orderBy('name').snapshots().map(
        (s) => s.docs.map((d) => (d.data()['name'] as String? ?? '')).where((n) => n.isNotEmpty).toList());
  }

  Future<void> addDepartment(String name) {
    final clean = name.trim();
    if (clean.isEmpty) throw Exception('Department name is required.');
    return _departments.add({
      'name': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDepartment(String id) =>
      _departments.doc(id).delete();

  Future<List<({String id, String name})>> departmentEntries() async {
    final s = await _departments.orderBy('name').get();
    return [
      for (final d in s.docs)
        (id: d.id, name: (d.data()['name'] as String? ?? ''))
    ];
  }
}
