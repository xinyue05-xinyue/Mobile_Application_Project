import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/emergency_response.dart';

class EmergencyResponseRepository {
  const EmergencyResponseRepository(this.client);

  final SupabaseClient client;

  Future<Set<String>> getMyPendingRequestIds() async {
    final statuses = await getMyResponseStatuses();
    return statuses.entries
        .where((entry) => entry.value == 'pending')
        .map((entry) => entry.key)
        .toSet();
  }

  Future<Map<String, String>> getMyResponseStatuses() async {
    final user = client.auth.currentUser;
    if (user == null) return const <String, String>{};
    await client.rpc('refresh_my_donation_commitments');
    final rows = await client
        .from('emergency_responses')
        .select('request_id, status')
        .eq('donor_id', user.id);
    return {
      for (final row in rows)
        row['request_id']! as String: row['status']! as String,
    };
  }

  Future<void> cancel(String requestId) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.rpc(
      'cancel_my_emergency_response',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> respond(String requestId) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.rpc(
      'respond_to_emergency',
      params: {'p_request_id': requestId},
    );
  }

  Future<bool> hasActiveDonationCommitment() async {
    final value = await client.rpc('has_active_donation_commitment');
    return value == true;
  }

  Future<List<EmergencyResponse>> getForRequest(String requestId) async {
    final rows = await client
        .from('emergency_responses')
        .select(
          'id, request_id, donor_id, status, created_at, '
          'donor:profiles!emergency_responses_donor_id_fkey('
          'full_name, blood_type, phone, next_eligible_date)',
        )
        .eq('request_id', requestId)
        .order('created_at');
    return rows.map(EmergencyResponse.fromMap).toList();
  }

  Future<EmergencyResponse?> getForRequestAndDonor({
    required String requestId,
    required String donorId,
  }) async {
    final rows = await client
        .from('emergency_responses')
        .select(
          'id, request_id, donor_id, status, created_at, '
          'donor:profiles!emergency_responses_donor_id_fkey('
          'full_name, blood_type, phone, next_eligible_date)',
        )
        .eq('request_id', requestId)
        .eq('donor_id', donorId)
        .limit(1);
    if (rows.isEmpty) return null;
    return EmergencyResponse.fromMap(rows.first);
  }

  Future<void> verifyDonation({
    required String responseId,
    required DateTime nextEligibleDate,
  }) async {
    await client.rpc(
      'verify_emergency_donation',
      params: {
        'p_response_id': responseId,
        'p_next_eligible_date': nextEligibleDate
            .toIso8601String()
            .split('T')
            .first,
      },
    );
  }
}
