import 'package:flutter/material.dart';
import '../../widgets/event_schedule.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/admin_event_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donation_event.dart';
import 'event_form_screen.dart';
import 'event_registrations_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  late Future<List<DonationEvent>> events;

  @override
  void initState() {
    super.initState();
    events = loadEvents();
  }

  Future<List<DonationEvent>> loadEvents() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return AdminEventRepository(client).getOwnEvents();
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String displayStatus(DonationEvent event) {
    return switch (event.status) {
      'in_progress' => 'In progress',
      'ended' => 'Ended',
      'cancelled' => 'Cancelled',
      _ => 'Upcoming',
    };
  }

  Future<void> openForm([DonationEvent? event]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: event)),
    );
    if (changed == true) {
      setState(() {
        events = loadEvents();
      });
    }
  }

  Future<void> cancel(DonationEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text('The event remains in the audit history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = SupabaseService.client;
    if (client == null) return;
    await AdminEventRepository(client).cancel(event.id);
    if (mounted) {
      setState(() {
        events = loadEvents();
      });
    }
  }

  Widget eventCard(DonationEvent event) {
    final status = displayStatus(event);
    final canModify = status == 'Upcoming';
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(event.venue)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(eventSchedule(event.startsAt, event.endsAt)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 19),
                const SizedBox(width: 8),
                Text('Status: $status'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventRegistrationsScreen(event: event),
                    ),
                  ),
                  child: const Text('Registrations'),
                ),
                if (canModify) ...[
                  OutlinedButton(
                    onPressed: () => openForm(event),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () => cancel(event),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget eventSection(
    String title,
    List<DonationEvent> items, {
    required bool expanded,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.organisationBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.donorMutedOutline),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppTheme.organisation,
        collapsedIconColor: AppTheme.organisation,
        backgroundColor: AppTheme.organisationBackground,
        collapsedBackgroundColor: AppTheme.organisationBackground,
        initiallyExpanded: expanded,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${items.length} event${items.length == 1 ? '' : 's'}'),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: items.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No events in this group.'),
                ),
              ]
            : items.map(eventCard).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.organisationBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.organisationHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.organisationHeaderTitleStyle,
        title: const Text('Manage Events'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.organisation,
        foregroundColor: Colors.white,
        onPressed: openForm,
        icon: const Icon(Icons.add),
        label: const Text('Create event'),
      ),
      body: FutureBuilder<List<DonationEvent>>(
        future: events,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load events: ${snapshot.error}'),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No events created yet.'));
          }
          final inProgress = items
              .where((event) => displayStatus(event) == 'In progress')
              .toList();
          final upcoming = items
              .where((event) => displayStatus(event) == 'Upcoming')
              .toList();
          final ended = items
              .where((event) => displayStatus(event) == 'Ended')
              .toList();
          final cancelled = items
              .where((event) => displayStatus(event) == 'Cancelled')
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              eventSection(
                'In progress',
                inProgress,
                expanded: inProgress.isNotEmpty,
              ),
              eventSection('Upcoming', upcoming, expanded: inProgress.isEmpty),
              eventSection('Ended', ended, expanded: false),
              if (cancelled.isNotEmpty)
                eventSection('Cancelled', cancelled, expanded: false),
            ],
          );
        },
      ),
    );
  }
}
