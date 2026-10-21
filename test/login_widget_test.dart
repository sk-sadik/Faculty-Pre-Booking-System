import 'package:faculty_pre_booking/features/auth/domain/entities/app_user.dart';
import 'package:faculty_pre_booking/features/auth/domain/repositories/auth_repository.dart';
import 'package:faculty_pre_booking/features/auth/presentation/providers/auth_providers.dart';
import 'package:faculty_pre_booking/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test double: no Firebase involved.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  final AppUser? user;
  String? lastEmail;
  String? lastPassword;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AppUser?> currentUser() async => user;

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (user == null) throw Exception('Invalid credentials');
    return user!;
  }

  @override
  Future<AppUser> signUp(RegisterParams params) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateProfile(AppUser user) async {}

  @override
  Stream<AppUser?> watchProfile(String uid) => Stream.value(user);
}

const _demoUser = AppUser(
  uid: 's1',
  email: 'rohan@college.edu',
  role: UserRole.student,
  name: 'Rohan Verma',
);

Widget _harness(FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows validation errors on empty submit',
        (tester) async {
      await tester.pumpWidget(_harness(FakeAuthRepository()));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await tester.pumpWidget(_harness(FakeAuthRepository()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'not-an-email');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('signs in with valid credentials', (tester) async {
      final fake = FakeAuthRepository(user: _demoUser);
      await tester.pumpWidget(_harness(fake));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'rohan@college.edu');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'student123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(fake.lastEmail, 'rohan@college.edu');
      expect(fake.lastPassword, 'student123');
      // No error snackbar on success.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows a friendly error on failed sign-in',
        (tester) async {
      await tester.pumpWidget(_harness(FakeAuthRepository()));
      await tester.enterText(
          find.byType(TextFormField).at(0), 'ghost@college.edu');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'wrongpass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
