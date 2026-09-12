class DonorLevel {
  const DonorLevel._();

  static String name(int donationCount, {bool short = false}) {
    final level = donationCount >= 16
        ? 'Gold'
        : donationCount >= 6
        ? 'Silver'
        : donationCount >= 1
        ? 'Bronze'
        : 'New donor';
    return short || level == 'New donor' ? level : '$level Donor';
  }

  static int? nextTarget(int donationCount) {
    if (donationCount < 1) return 1;
    if (donationCount < 6) return 6;
    if (donationCount < 16) return 16;
    return null;
  }

  static double progress(int donationCount) {
    if (donationCount >= 16) return 1;
    if (donationCount >= 6) {
      return ((donationCount - 5) / 10).clamp(0, 1);
    }
    return (donationCount / 5).clamp(0, 1);
  }

  static String progressLabel(int donationCount) {
    final target = nextTarget(donationCount);
    if (target == null) return 'Highest app recognition level reached';
    final remaining = target - donationCount;
    return '$remaining more verified ${remaining == 1 ? 'donation' : 'donations'} to ${name(target)}';
  }
}
