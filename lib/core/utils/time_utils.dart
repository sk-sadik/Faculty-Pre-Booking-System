/// Pure-Dart date/time helpers shared by slot generation and booking logic.
/// No Flutter imports so this file stays unit-testable.
library;

const int minutesPerDay = 24 * 60;

/// Parses an "HH:mm" string (24h) into minutes since midnight.
/// Throws [FormatException] on invalid input.
int parseHm(String hm) {
  final parts = hm.split(':');
  if (parts.length != 2) throw FormatException('Invalid time: $hm');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  if (h < 0 || h > 23 || m < 0 || m > 59) {
    throw FormatException('Invalid time: $hm');
  }
  return h * 60 + m;
}

/// Formats minutes since midnight as "HH:mm".
String formatHm(int minutes) {
  final v = minutes % minutesPerDay;
  final h = v ~/ 60;
  final m = v % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Canonical Firestore date key: "yyyy-MM-dd".
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Parses a "yyyy-MM-dd" key back into a [DateTime] (local, midnight).
DateTime parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) throw FormatException('Invalid date: $key');
  return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Combines a date with minutes-since-midnight into a [DateTime].
DateTime combine(DateTime date, int minutes) => DateTime(
    date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
