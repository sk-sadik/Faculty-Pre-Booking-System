import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_home_screen.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/appointments/presentation/screens/booking_detail_screen.dart';
import '../../features/faculty/presentation/screens/faculty_calendar_screen.dart';
import '../../features/faculty/presentation/screens/faculty_home_screen.dart';
import '../../features/faculty/presentation/screens/faculty_settings_screen.dart';
import '../../features/faculty/presentation/screens/faculty_shell.dart';
import '../../features/faculty/presentation/screens/manage_availability_screen.dart';
import '../../features/faculty/presentation/screens/request_detail_screen.dart';
import '../../features/faculty/presentation/screens/requests_inbox_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/student/presentation/screens/booking_confirmation_screen.dart';
import '../../features/student/presentation/screens/booking_form_screen.dart';
import '../../features/student/presentation/screens/faculty_detail_screen.dart';
import '../../features/student/presentation/screens/faculty_directory_screen.dart';
import '../../features/student/presentation/screens/my_bookings_screen.dart';
import '../../features/student/presentation/screens/student_home_screen.dart';
import '../../features/student/presentation/screens/student_shell.dart';
import '../providers/app_providers.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter with role-based guards.
///
/// Rules (Phase 1):
/// - `/` splash: always allowed; redirects once auth state resolves.
/// - Unauthenticated users can only visit onboarding/login/register/forgot.
/// - Authenticated users are forced onto their role home
///   (`/student`, `/faculty`, `/admin`) and blocked from auth pages.
/// - First launch goes to onboarding until `onboarding_seen_v1` is set.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingSeen = ref.watch(onboardingSeenProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    refreshListenable: _RefRefreshListenable(ref),
    redirect: (context, state) {
      final loc = state.uri.toString();
      final isAuthPage = loc == RouteNames.login ||
          loc == RouteNames.register ||
          loc == RouteNames.forgotPassword;

      // While Firebase/SharedPrefs still load, stay on splash.
      if (authState.isLoading || onboardingSeen.isLoading) {
        return loc == RouteNames.splash ? null : RouteNames.splash;
      }

      final seen = onboardingSeen.value ?? true;
      if (!seen &&
          loc != RouteNames.onboarding &&
          loc != RouteNames.splash) {
        return RouteNames.onboarding;
      }

      final user = authState.valueOrNull;
      if (user == null) {
        if (isAuthPage ||
            loc == RouteNames.onboarding ||
            loc == RouteNames.splash) {
          // Splash collapses to login once we know there is no session.
          if (loc == RouteNames.splash) {
            return seen ? RouteNames.login : RouteNames.onboarding;
          }
          return null;
        }
        return RouteNames.login;
      }

      // Signed in: keep them inside their role area.
      final home = switch (user.role) {
        UserRole.student => RouteNames.studentHome,
        UserRole.faculty => RouteNames.facultyHome,
        UserRole.admin => RouteNames.adminHome,
      };
      if (isAuthPage ||
          loc == RouteNames.splash ||
          loc == RouteNames.onboarding) {
        return home;
      }
      // Cross-role protection.
      if (loc.startsWith(RouteNames.studentHome) &&
          user.role != UserRole.student) {
        return home;
      }
      if (loc.startsWith(RouteNames.facultyHome) &&
          user.role != UserRole.faculty) {
        return home;
      }
      if (loc.startsWith(RouteNames.adminHome) &&
          user.role != UserRole.admin) {
        return home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => StudentShell(
          navigationShell: shell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.studentHome,
                builder: (_, __) => const StudentHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.studentDirectory,
                builder: (_, __) =>
                    const FacultyDirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.studentBookings,
                builder: (_, __) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.studentNotifications,
                builder: (_, __) => const NotificationsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/student/faculty/:fid',
        builder: (_, state) => FacultyDetailScreen(
            facultyId: state.pathParameters['fid']!),
      ),
      GoRoute(
        path: '/student/book/:fid',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return BookingFormScreen(
            facultyId: state.pathParameters['fid']!,
            date: q['date'] ?? '',
            startTime: q['start'] ?? '',
            endTime: q['end'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/student/confirmed/:id',
        builder: (_, state) => BookingConfirmationScreen(
            appointmentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/booking/:id',
        builder: (_, state) => BookingDetailScreen(
            appointmentId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => FacultyShell(
          navigationShell: shell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.facultyHome,
                builder: (_, __) => const FacultyHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.facultyInbox,
                builder: (_, __) => const RequestsInboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.facultyAvailability,
                builder: (_, __) =>
                    const ManageAvailabilityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.facultyCalendar,
                builder: (_, __) => const FacultyCalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.facultyNotifications,
                builder: (_, __) => const NotificationsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.facultySettings,
        builder: (_, __) => const FacultySettingsScreen(),
      ),
      GoRoute(
        path: '/faculty/request/:id',
        builder: (_, state) => RequestDetailScreen(
            appointmentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.adminHome,
        builder: (_, __) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

/// Rebuilds GoRouter whenever Riverpod state used in [redirect] changes.
class _RefRefreshListenable extends ChangeNotifier {
  _RefRefreshListenable(Ref ref) {
    // ref.listen inside a Provider keeps the subscription alive
    // for the lifetime of the provider — the standard Riverpod pattern
    // for GoRouter refreshListenable.
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, __) => notifyListeners());
  }
}
