import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event_registration.dart';

class EventRegistrationRepository {
  const EventRegistrationRepository(this.client);

  final SupabaseClient client;

  Future<Set<String>> getMyRegisteredEventIds() async {
    return (await getMyRegistrationStatuses()).entries
        .where((entry) => entry.value == 'registered')
        .map((entry) => entry.key)
        .toSet();
  }

  Future<Map<String, String>> getMyRegistrationStatuses() async {
    final user = client.auth.currentUser;
    if (user == null) return const {};
    await client.rpc('refresh_my_donation_commitments');
    final rows = await client
        .from('event_registrations')
        .select('event_id, status')
        .eq('donor_id', user.id);
    return {
      for (final row in rows)
        row['event_id']! as String: row['status']! as String,
    };
  }

  Future<void> register(String eventId) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.rpc('register_for_event', params: {'p_event_id': eventId});
  }

  Future<void> cancel(String eventId) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.rpc(
      'cancel_my_event_registration',
      params: {'p_event_id': eventId},
    );
  }

  Future<bool> hasActiveDonationCommitment() async {
    final value = await client.rpc('has_active_donation_commitment');
    return value == true;
  }

  Future<List<EventRegistration>> getForEvent(String eventId) async {
    final rows = await client
        .from('event_registrations')
        .select(
          'id, event_id, donor_id, status, registered_at, '
          'donor:profiles!event_registrations_donor_id_fkey('
          'full_name, blood_type, phone, next_eligible_date)',
        )
        .eq('event_id', eventId)
        .order('registered_at');
    return rows.map(EventRegistration.fromMap).toList();
  }

  Future<EventRegistration?> getForEventAndDonor({
    required String eventId,
    required String donorId,
  }) async {
    final rows = await client
        .from('event_registrations')
        .select(
          'id, event_id, donor_id, status, registered_at, '
          'donor:profiles!event_registrations_donor_id_fkey('
          'full_name, blood_type, phone, next_eligible_date)',
        )
        .eq('event_id', eventId)
        .eq('donor_id', donorId)
        .limit(1);
    if (rows.isEmpty) return null;
    return EventRegistration.fromMap(rows.first);
  }

  Future<void> verifyDonation({
    required String registrationId,
    required DateTime nextEligibleDate,
  }) async {
    await client.rpc(
      'verify_event_donation',
      params: {
        'p_registration_id': registrationId,
        'p_next_eligible_date': nextEligibleDate
            .toIso8601String()
            .split('T')
            .first,
      },
    );
  }

  Future<void> verifyQr({
    required String eventId,
    required String donorId,
  }) async {
    await client.rpc(
      'verify_event_qr',
      params: {'p_event_id': eventId, 'p_donor_id': donorId},
    );
  }
}
