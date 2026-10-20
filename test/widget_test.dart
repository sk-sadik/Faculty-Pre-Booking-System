import 'package:faculty_pre_booking/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators (Phase 1 auth)', () {
    test('email validation', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('student@college.edu'), isNull);
    });

    test('password validation', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('required fields', () {
      expect(Validators.required('', 'Name'), isNotNull);
      expect(Validators.required('Aarav', 'Name'), isNull);
    });
  });
}
