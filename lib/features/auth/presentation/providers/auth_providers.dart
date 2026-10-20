import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

/// Emits the signed-in user's profile (null when signed out).
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Async controller for sign-in / sign-up / reset / sign-out actions.
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<AppUser?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = AsyncValue.data(user);
      _ref.invalidate(authStateProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AppUser?> signUp(RegisterParams params) async {
    state = const AsyncValue.loading();
    try {
      final user =
          await _ref.read(authRepositoryProvider).signUp(params);
      state = AsyncValue.data(user);
      _ref.invalidate(authStateProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(authRepositoryProvider).sendPasswordReset(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    _ref.invalidate(authStateProvider);
    state = const AsyncValue.data(null);
  }
}

/// Live profile of the currently signed-in Firebase user.
final currentProfileProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
