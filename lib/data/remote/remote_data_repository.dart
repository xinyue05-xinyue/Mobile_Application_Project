import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation_centre.dart';
import '../../models/donation_event.dart';

// REMOTE REPOSITORY: Downloads shared centre and event records from Supabase.

class RemoteDataRepository {
  const RemoteDataRepository(this.client);

  final SupabaseClient client;

  // Retrieves the latest organisation-created event venues.
  Future<List<DonationCentre>> getCentres() async {
    final rows = await client.from('donation_centres').select().order('name');
    return rows.map(DonationCentre.fromMap).toList();
  }

  // Retrieves events and attaches each organisation's display name.
  Future<List<DonationEvent>> getEvents() async {
    final rows = await client
        .from('donation_events')
        .select()
        .neq('status', 'cancelled')
        .order('starts_at');
    final ownerIds = rows
        .map((row) => row['created_by'] as String)
        .toSet()
        .toList();
    if (ownerIds.isNotEmpty) {
      final profiles = await client
          .from('organisation_profiles')
          .select('owner_id, display_name')
          .inFilter('owner_id', ownerIds);
      final names = {
        for (final profile in profiles)
          profile['owner_id']: profile['display_name'],
      };
      for (final row in rows) {
        row['organiser_name'] = names[row['created_by']];
      }
    }
    return rows.map(DonationEvent.fromMap).toList();
  }
}
