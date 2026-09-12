import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/models/donor_level.dart';

void main() {
  test('levels use verified donation count at each boundary', () {
    expect(DonorLevel.name(0), 'New donor');
    expect(DonorLevel.name(1), 'Bronze Donor');
    expect(DonorLevel.name(4), 'Bronze Donor');
    expect(DonorLevel.name(5), 'Bronze Donor');
    expect(DonorLevel.name(6), 'Silver Donor');
    expect(DonorLevel.name(15), 'Silver Donor');
    expect(DonorLevel.name(16), 'Gold Donor');
    expect(DonorLevel.nextTarget(16), isNull);
  });
  test('progress measures donations between levels', () {
    expect(DonorLevel.progress(0), 0);
    expect(DonorLevel.progress(1), 0.2);
    expect(DonorLevel.progress(5), 1);
    expect(DonorLevel.progress(6), 0.1);
    expect(DonorLevel.progress(10), 0.5);
    expect(DonorLevel.progress(15), 1);
    expect(DonorLevel.progress(16), 1);
  });
}
