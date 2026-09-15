class DonorProfile {
  const DonorProfile({
    required this.id,
    required this.fullName,
    required this.notificationsEnabled,
    this.bloodType,
    this.phone,
    this.state,
    this.dateOfBirth,
    this.nextEligibleDate,
  });

  final String id;
  final String fullName;
  final String? bloodType;
  final String? phone;
  final String? state;
  final DateTime? dateOfBirth;
  final DateTime? nextEligibleDate;
  final bool notificationsEnabled;

  factory DonorProfile.fromMap(Map<String, Object?> map) => DonorProfile(
    id: map['id']! as String,
    fullName: map['full_name']! as String,
    bloodType: map['blood_type'] as String?,
    phone: map['phone'] as String?,
    state: map['state'] as String?,
    dateOfBirth: _date(map['date_of_birth']),
    nextEligibleDate: _date(map['next_eligible_date']),
    notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
  );

  static DateTime? _date(Object? value) {
    return value == null ? null : DateTime.tryParse(value as String);
  }
}
