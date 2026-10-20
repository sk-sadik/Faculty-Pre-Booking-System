import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

/// Firebase implementation: FirebaseAuth + users/{uid} in Firestore.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      return _fetchProfile(fbUser.uid, fbUser.email);
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return _fetchProfile(fbUser.uid, fbUser.email);
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) {
        throw const AuthFailure('Sign-in failed. Please try again.');
      }
      final profile =
          await _fetchProfile(fbUser.uid, fbUser.email ?? email.trim());
      if (profile == null) {
        throw const AuthFailure(
            'Profile not found. Contact admin to create your role profile.');
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'signIn FirebaseAuthException: code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? friendlyAuthMessage(e.code)}');
    } on FirebaseException catch (e) {
      debugPrint(
          'signIn FirebaseException: plugin=${e.plugin} code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? 'Firestore operation failed.'}');
    } on Failure {
      rethrow;
    } catch (e, st) {
      debugPrint('signIn unexpected error: $e\n$st');
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<AppUser> signUp(RegisterParams params) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: params.email.trim(),
        password: params.password,
      );
      final fbUser = cred.user;
      if (fbUser == null) {
        throw const AuthFailure('Sign-up failed. Please try again.');
      }
      await fbUser.updateDisplayName(params.name.trim());
      final model = AppUserModel(
        uid: fbUser.uid,
        email: params.email.trim(),
        role: params.role,
        name: params.name.trim(),
        phone: params.phone?.trim().isEmpty == true
            ? null
            : params.phone?.trim(),
        department: params.department,
        rollNumber: params.rollNumber?.trim().isEmpty == true
            ? null
            : params.rollNumber?.trim(),
        year: params.year,
        employeeId: params.employeeId?.trim().isEmpty == true
            ? null
            : params.employeeId?.trim(),
        designation: params.designation?.trim().isEmpty == true
            ? null
            : params.designation?.trim(),
        cabinNumber: params.cabinNumber?.trim().isEmpty == true
            ? null
            : params.cabinNumber?.trim(),
      );
      await _users.doc(fbUser.uid).set(model.toMap());
      final created =
          await _fetchProfile(fbUser.uid, params.email.trim());
      return created ?? model;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'signUp FirebaseAuthException: code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? friendlyAuthMessage(e.code)}');
    } on FirebaseException catch (e) {
      debugPrint(
          'signUp FirebaseException: plugin=${e.plugin} code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? 'Firestore operation failed.'}');
    } on Failure {
      rethrow;
    } catch (e, st) {
      debugPrint('signUp unexpected error: $e\n$st');
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'sendPasswordReset FirebaseAuthException: code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? friendlyAuthMessage(e.code)}');
    } on FirebaseException catch (e) {
      debugPrint(
          'sendPasswordReset FirebaseException: plugin=${e.plugin} code=${e.code} message=${e.message}');
      throw AuthFailure(
          '[${e.code}] ${e.message ?? 'Firestore operation failed.'}');
    } catch (e, st) {
      debugPrint('sendPasswordReset unexpected error: $e\n$st');
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> updateProfile(AppUser user) async {
    await _users.doc(user.uid).update({
      'name': user.name,
      'phone': user.phone,
      'department': user.department,
      'photoUrl': user.photoUrl,
      'rollNumber': user.rollNumber,
      'year': user.year,
      'employeeId': user.employeeId,
      'designation': user.designation,
      'cabinNumber': user.cabinNumber,
      if (user.fcmToken != null) 'fcmToken': user.fcmToken,
      if (user.isAvailableNow != null)
        'isAvailableNow': user.isAvailableNow,
      if (user.maxPerDay != null) 'maxPerDay': user.maxPerDay,
      if (user.bufferMinutes != null)
        'bufferMinutes': user.bufferMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<AppUser?> _fetchProfile(String uid, String? fallbackEmail) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUserModel.fromMap(doc.id, doc.data()!);
  }
}
