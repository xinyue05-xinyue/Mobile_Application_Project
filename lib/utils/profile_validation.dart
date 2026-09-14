class ProfileValidation {
  static final RegExp _namePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
  static final RegExp _phonePattern = RegExp(r'^0[0-9]{9,10}$');

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Full name is required.';
    if (!_namePattern.hasMatch(name)) {
      return 'Use letters and spaces only.';
    }
    return null;
  }

  static String? phone(String? value, {bool required = true}) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return required ? 'Phone number is required.' : null;
    if (!_phonePattern.hasMatch(phone)) {
      return 'Enter a Malaysian phone number with 10 or 11 digits.';
    }
    return null;
  }

  static bool isAtLeast18(DateTime? dateOfBirth, {DateTime? today}) {
    if (dateOfBirth == null) return false;
    final current = today ?? DateTime.now();
    final eighteenthBirthday = DateTime(
      dateOfBirth.year + 18,
      dateOfBirth.month,
      dateOfBirth.day,
    );
    return !DateTime(
      current.year,
      current.month,
      current.day,
    ).isBefore(eighteenthBirthday);
  }
}
