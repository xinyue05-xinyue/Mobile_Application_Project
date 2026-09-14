import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/utils/profile_validation.dart';

void main() {
  group('full name validation', () {
    test('accepts alphabetic words separated by spaces', () {
      expect(ProfileValidation.fullName('Noelle Lee Jing Wen'), isNull);
    });

    test('rejects numbers and symbols', () {
      expect(ProfileValidation.fullName('Noelle123'), isNotNull);
      expect(ProfileValidation.fullName('Noelle@Lee'), isNotNull);
    });
  });

  group('Malaysian phone validation', () {
    test('accepts local numbers containing 10 or 11 digits', () {
      expect(ProfileValidation.phone('0123456789'), isNull);
      expect(ProfileValidation.phone('01123456789'), isNull);
    });

    test('rejects invalid length, prefix and characters', () {
      expect(ProfileValidation.phone('1234567890'), isNotNull);
      expect(ProfileValidation.phone('012345678'), isNotNull);
      expect(ProfileValidation.phone('01234abcde'), isNotNull);
    });
  });

  group('event registration age', () {
    final today = DateTime(2026, 9, 14);

    test('accepts the eighteenth birthday and older donors', () {
      expect(
        ProfileValidation.isAtLeast18(DateTime(2008, 9, 14), today: today),
        isTrue,
      );
      expect(
        ProfileValidation.isAtLeast18(DateTime(2000, 1, 1), today: today),
        isTrue,
      );
    });

    test('rejects donors younger than eighteen or without a birth date', () {
      expect(
        ProfileValidation.isAtLeast18(DateTime(2008, 9, 15), today: today),
        isFalse,
      );
      expect(ProfileValidation.isAtLeast18(null, today: today), isFalse);
    });
  });
}
