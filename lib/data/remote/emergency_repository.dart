import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/emergency_request.dart';

class EmergencyRepository {
  const EmergencyRepository(this.client);

  final SupabaseClient client;

  Future<List<EmergencyRequest>> getHospitalRequests() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final rows = await client
        .from('emergency_requests')
        .select()
        .eq('hospital_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(EmergencyRequest.fromMap).toList();
  }

  Future<EmergencyRequest?> getOwnedRequest(String requestId) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final rows = await client
        .from('emergency_requests')
        .select()
        .eq('id', requestId)
        .eq('hospital_id', user.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return EmergencyRequest.fromMap(rows.first);
  }

  Future<List<EmergencyRequest>> getMatchingDonorRequests() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final profile = await client
        .from('profiles')
        .select('blood_type, next_eligible_date')
        .eq('id', user.id)
        .single();
    final bloodType = profile['blood_type'] as String?;
    if (bloodType == null) return const [];

    final eligibleDateValue = profile['next_eligible_date'] as String?;
    final eligibleDate = eligibleDateValue == null
        ? null
        : DateTime.tryParse(eligibleDateValue);
    final today = DateTime.now();
    if (eligibleDate != null && eligibleDate.isAfter(today)) return const [];

    final rows = await client
        .from('emergency_requests')
        .select()
        .eq('status', 'active')
        .eq('blood_type', bloodType)
        .gt('deadline', DateTime.now().toUtc().toIso8601String())
        .order('deadline');
    return rows.map(EmergencyRequest.fromMap).toList();
  }

  Future<void> create({
    required String bloodType,
    required String urgency,
    required DateTime deadline,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.from('emergency_requests').insert({
      'hospital_id': user.id,
      'blood_type': bloodType,
      'urgency': urgency,
      'deadline': deadline.toUtc().toIso8601String(),
      'status': 'active',
    });
  }

  Future<List<EmergencyRequest>> getRequestsByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await client
        .from('emergency_requests')
        .select()
        .inFilter('id', ids.toList())
        .order('deadline', ascending: false);
    return rows.map(EmergencyRequest.fromMap).toList();
  }

  Future<void> updateStatus(String id, String status) async {
    if (status != 'fulfilled' && status != 'cancelled') {
      throw ArgumentError('Invalid emergency request status.');
    }
    await client
        .from('emergency_requests')
        .update({'status': status})
        .eq('id', id);
  }
}
