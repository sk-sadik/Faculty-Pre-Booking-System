/// App-wide constants.
abstract class AppConstants {
  static const String appName = 'Faculty Pre-Booking';
  static const String onboardingSeenKey = 'onboarding_seen_v1';
  static const String themeModeKey = 'theme_mode_v1';

  static const List<String> departments = [
    'Computer Science',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Mathematics',
    'Physics',
    'Business Administration',
    'Other',
  ];

  static const List<String> years = ['1st', '2nd', '3rd', '4th', 'Other'];

  static const int bookingCancelCutoffHours = 2;
}
