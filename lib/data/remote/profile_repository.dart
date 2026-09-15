import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation_record.dart';
import '../../models/donor_profile.dart';
import '../../models/profile_overview.dart';
import '../../models/reward_transaction.dart';
import '../local/local_cache_service.dart';

// PROFILE REPOSITORY: Loads authoritative donor data and maintains offline copies.

class ProfileRepository {
  const ProfileRepository(this.client);

  final SupabaseClient client;

  Future<DonorProfile> getCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    try {
      final row = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      await LocalCacheService.instance.saveMap(user.id, 'donor_profile', row);
      return DonorProfile.fromMap(row);
    } on Exception {
      final cached = await LocalCacheService.instance.loadMap(
        user.id,
        'donor_profile',
      );
      if (cached == null) rethrow;
      return DonorProfile.fromMap(cached);
    }
  }

  Future<ProfileOverview> getOverview() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');

    Map<String, Object?> profileRow;
    List<Map<String, Object?>> donationRows;
    List<Map<String, Object?>> rewardRows;
    try {
      final results = await Future.wait([
        client.from('profiles').select().eq('id', user.id).single(),
        client
            .from('donations')
            .select(
              'id, donation_date, verification_status, event_id, emergency_request_id',
            )
            .eq('donor_id', user.id)
            .eq('verification_status', 'verified')
            .order('donation_date', ascending: false),
        client
            .from('reward_transactions')
            .select('id, points, transaction_type, created_at')
            .eq('donor_id', user.id)
            .order('created_at', ascending: false),
      ]);
      profileRow = Map<String, Object?>.from(results[0] as Map);
      donationRows = (results[1] as List).cast<Map<String, Object?>>().toList();
      rewardRows = (results[2] as List).cast<Map<String, Object?>>().toList();
      await Future.wait([
        LocalCacheService.instance.saveMap(
          user.id,
          'donor_profile',
          profileRow,
        ),
        LocalCacheService.instance.saveList(
          user.id,
          'donation_history',
          donationRows,
        ),
        LocalCacheService.instance.saveList(
          user.id,
          'reward_transactions',
          rewardRows,
        ),
      ]);
    } on Exception {
      final cached = await Future.wait([
        LocalCacheService.instance.loadMap(user.id, 'donor_profile'),
        LocalCacheService.instance.loadList(user.id, 'donation_history'),
        LocalCacheService.instance.loadList(user.id, 'reward_transactions'),
      ]);
      if (cached.any((value) => value == null)) rethrow;
      profileRow = cached[0]! as Map<String, Object?>;
      donationRows = cached[1]! as List<Map<String, Object?>>;
      rewardRows = cached[2]! as List<Map<String, Object?>>;
    }

    final profile = DonorProfile.fromMap(profileRow);
    final donations = donationRows.map(DonationRecord.fromMap).toList();
    final rewards = rewardRows.map(RewardTransaction.fromMap).toList();
    final rewardPoints = rewards.fold<int>(
      0,
      (total, reward) => total + reward.points,
    );

    return ProfileOverview(
      profile: profile,
      donations: donations,
      rewardPoints: rewardPoints,
      rewards: rewards,
    );
  }

  Future<void> updateProfile({
    required String fullName,
    required String? bloodType,
    required String phone,
    required String? state,
    required DateTime? dateOfBirth,
    required bool notificationsEnabled,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client
        .from('profiles')
        .update({
          'full_name': fullName,
          'blood_type': bloodType,
          'phone': phone.isEmpty ? null : phone,
          'state': state,
          'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
          'notifications_enabled': notificationsEnabled,
        })
        .eq('id', user.id);
  }

  Future<void> updateBasicProfile({required String fullName}) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', user.id);
  }
}
