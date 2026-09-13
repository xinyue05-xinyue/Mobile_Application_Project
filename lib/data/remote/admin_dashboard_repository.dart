import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation_event.dart';

class AdminDashboardRepository {
  const AdminDashboardRepository(this.client);

  final SupabaseClient client;

  Future<AdminDashboardSummary> getSummary() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');

    final eventRows = await client
        .from('donation_events')
        .select(
          'id, title, venue, starts_at, ends_at, status, description, '
          'latitude, longitude, image_path, created_by, publish_at',
        )
        .eq('created_by', user.id);
    final now = DateTime.now();
    final events = eventRows.map(DonationEvent.fromMap).toList();
    final upcomingCount = eventRows.where((event) {
      return event['status'] != 'cancelled' &&
          DateTime.parse(event['ends_at']! as String).toLocal().isAfter(now);
    }).length;
    final eventIds = eventRows.map((event) => event['id']! as String).toList();

    var registrationCount = 0;
    var attendedCount = 0;
    final bloodGroups = <String, int>{};
    if (eventIds.isNotEmpty) {
      final registrationRows = await client
          .from('event_registrations')
          .select(
            'id, status, donor:profiles!event_registrations_donor_id_fkey('
            'blood_type)',
          )
          .inFilter('event_id', eventIds)
          .neq('status', 'cancelled');
      registrationCount = registrationRows.length;
      for (final row in registrationRows) {
        final status = row['status'] as String?;
        if (status == 'attended' || status == 'verified') attendedCount++;
        final donor = row['donor'] as Map<String, Object?>?;
        final bloodType = donor?['blood_type'] as String?;
        if (bloodType != null && bloodType.isNotEmpty) {
          bloodGroups[bloodType] = (bloodGroups[bloodType] ?? 0) + 1;
        }
      }
    }

    DonationEvent? currentEvent;
    DonationEvent? nextEvent;
    final ordered = [...events]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    for (final event in ordered) {
      if (event.status == 'cancelled') continue;
      if (!now.isBefore(event.startsAt) && now.isBefore(event.endsAt)) {
        currentEvent = event;
        break;
      }
      if (event.startsAt.isAfter(now)) nextEvent ??= event;
    }

    return AdminDashboardSummary(
      upcomingEvents: upcomingCount,
      donorRegistrations: registrationCount,
      attendedDonors: attendedCount,
      bloodGroups: bloodGroups,
      focusEvent: currentEvent ?? nextEvent,
      focusEventIsActive: currentEvent != null,
    );
  }

  Future<List<AdminRegistrationDetail>> getRegistrationDetails() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final eventRows = await client
        .from('donation_events')
        .select('id, title, starts_at, ends_at')
        .eq('created_by', user.id);
    if (eventRows.isEmpty) return const [];
    final events = {
      for (final row in eventRows)
        row['id']! as String: (
          title: row['title']! as String,
          startsAt: DateTime.parse(row['starts_at']! as String).toLocal(),
          endsAt: DateTime.parse(row['ends_at']! as String).toLocal(),
        ),
    };
    final rows = await client
        .from('event_registrations')
        .select(
          'id, event_id, status, registered_at, '
          'donor:profiles!event_registrations_donor_id_fkey(full_name, blood_type)',
        )
        .inFilter('event_id', events.keys.toList())
        .neq('status', 'cancelled')
        .order('registered_at', ascending: false);
    return rows.map((row) {
      final donor = row['donor'] as Map<String, Object?>?;
      final event = events[row['event_id']! as String]!;
      return AdminRegistrationDetail(
        donorName: donor?['full_name'] as String? ?? 'Donor',
        bloodType: donor?['blood_type'] as String?,
        eventTitle: event.title,
        eventStartsAt: event.startsAt,
        eventEndsAt: event.endsAt,
        status: row['status']! as String,
        registeredAt: DateTime.parse(row['registered_at']! as String).toLocal(),
      );
    }).toList();
  }

  Future<List<AdminEventAnalytics>> getEventAnalytics() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final eventRows = await client
        .from('donation_events')
        .select('id, title, starts_at, ends_at, status')
        .eq('created_by', user.id)
        .neq('status', 'cancelled')
        .order('starts_at', ascending: false);
    if (eventRows.isEmpty) return const [];

    final eventIds = eventRows.map((row) => row['id']! as String).toList();
    final registrationRows = await client
        .from('event_registrations')
        .select(
          'event_id, status, donor:profiles!event_registrations_donor_id_fkey('
          'blood_type)',
        )
        .inFilter('event_id', eventIds)
        .neq('status', 'cancelled');

    final registrations = <String, int>{};
    final verified = <String, int>{};
    final bloodGroups = <String, Map<String, int>>{};
    for (final row in registrationRows) {
      final eventId = row['event_id']! as String;
      registrations[eventId] = (registrations[eventId] ?? 0) + 1;
      final status = row['status'] as String?;
      if (status == 'attended' || status == 'verified') {
        verified[eventId] = (verified[eventId] ?? 0) + 1;
      }
      final donor = row['donor'] as Map<String, Object?>?;
      final bloodType = donor?['blood_type'] as String?;
      if (bloodType != null && bloodType.isNotEmpty) {
        final groups = bloodGroups.putIfAbsent(eventId, () => {});
        groups[bloodType] = (groups[bloodType] ?? 0) + 1;
      }
    }

    return eventRows.map((row) {
      final id = row['id']! as String;
      return AdminEventAnalytics(
        eventId: id,
        title: row['title']! as String,
        startsAt: DateTime.parse(row['starts_at']! as String).toLocal(),
        endsAt: DateTime.parse(row['ends_at']! as String).toLocal(),
        registrations: registrations[id] ?? 0,
        verified: verified[id] ?? 0,
        bloodGroups: bloodGroups[id] ?? const {},
      );
    }).toList();
  }
}

class AdminEventAnalytics {
  const AdminEventAnalytics({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.registrations,
    required this.verified,
    required this.bloodGroups,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final int registrations;
  final int verified;
  final Map<String, int> bloodGroups;
}

class AdminRegistrationDetail {
  const AdminRegistrationDetail({
    required this.donorName,
    required this.eventTitle,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.status,
    required this.registeredAt,
    this.bloodType,
  });

  final String donorName;
  final String? bloodType;
  final String eventTitle;
  final DateTime eventStartsAt;
  final DateTime eventEndsAt;
  final String status;
  final DateTime registeredAt;
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.upcomingEvents,
    required this.donorRegistrations,
    this.attendedDonors = 0,
    this.bloodGroups = const {},
    this.focusEvent,
    this.focusEventIsActive = false,
  });

  final int upcomingEvents;
  final int donorRegistrations;
  final int attendedDonors;
  final Map<String, int> bloodGroups;
  final DonationEvent? focusEvent;
  final bool focusEventIsActive;
}
