/// Central route paths. Keeps go_router locations in one place.
abstract class RouteNames {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const studentHome = '/student';
  static const studentDirectory = '/student/faculty';
  static const studentBookings = '/student/bookings';
  static const studentNotifications = '/student/notifications';

  /// Detail / booking flow (flat routes under /student, guarded by the same
  /// role check).
  static String facultyDetail(String fid) => '/student/faculty/$fid';
  static String bookingForm(String fid,
          {required String date,
          required String start,
          required String end}) =>
      '/student/book/$fid?date=$date&start=$start&end=$end';
  static String bookingConfirmed(String id) => '/student/confirmed/$id';
  static String studentBooking(String id) => '/student/booking/$id';

  static const facultyHome = '/faculty';
  static const facultyInbox = '/faculty/inbox';
  static const facultyAvailability = '/faculty/availability';
  static const facultyCalendar = '/faculty/calendar';
  static const facultyNotifications = '/faculty/notifications';
  static const facultySettings = '/faculty/settings';

  /// Faculty request detail (flat route under /faculty).
  static String facultyRequest(String id) => '/faculty/request/$id';

  static const notifications = '/notifications';
  static const adminHome = '/admin';
  static const profile = '/profile';
}
