import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/admin_dashboard_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donation_event.dart';
import '../../widgets/notification_button.dart';
import '../../widgets/signed_in_identity_card.dart';
import '../statistics_screen.dart';
import 'donor_analysis_screen.dart';
import 'event_registrations_screen.dart';
import 'manage_centres_screen.dart';
import 'manage_events_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboardSummary> summary = loadSummary();

  Future<AdminDashboardSummary> loadSummary() {
    final client = SupabaseService.client;
    if (client == null) {
      return Future.value(
        const AdminDashboardSummary(upcomingEvents: 0, donorRegistrations: 0),
      );
    }
    return AdminDashboardRepository(client).getSummary();
  }

  Future<void> refresh() async {
    final refreshed = loadSummary();
    setState(() => summary = refreshed);
    await refreshed;
  }

  Future<void> openEvents() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageEventsScreen()),
    );
    if (mounted) await refresh();
  }

  Future<void> openVenues() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageCentresScreen()),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.organisationBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.organisationHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.organisationHeaderTitleStyle,
      automaticallyImplyLeading: false,
      title: const Text('Organisation workspace'),
      actions: const [
        StatisticsIconButton(useOrganisationColors: true),
        NotificationButton(useOrganisationColors: true),
      ],
    ),
    body: FutureBuilder<AdminDashboardSummary>(
      future: summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(onRetry: refresh);
        }
        final value = snapshot.data!;
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const SignedInIdentityCard(
                roleLabel: 'Organisation admin',
                useInstitutionProfile: true,
              ),
              const SizedBox(height: 18),
              Text(
                'Today at a glance',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Manage events',
                      detail: '${value.upcomingEvents} open',
                      icon: Icons.event_outlined,
                      onTap: openEvents,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Donor analysis',
                      detail: '${value.donorRegistrations} registrations',
                      icon: Icons.analytics_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DonorAnalysisScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Event venues',
                      detail: 'Manage locations',
                      icon: Icons.location_on_outlined,
                      onTap: openVenues,
                    ),
                  ),
                ],
              ),
              if (value.focusEvent != null) ...[
                const SizedBox(height: 18),
                _FocusEventCard(
                  event: value.focusEvent!,
                  active: value.focusEventIsActive,
                  onRegistrations: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EventRegistrationsScreen(event: value.focusEvent!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _FocusEventCard extends StatelessWidget {
  const _FocusEventCard({
    required this.event,
    required this.active,
    required this.onRegistrations,
  });
  final DonationEvent event;
  final bool active;
  final VoidCallback onRegistrations;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.radio_button_checked : Icons.upcoming_outlined,
                color: AppTheme.organisation,
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Event happening now' : 'Next event ',
                style: const TextStyle(
                  color: AppTheme.organisation,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(event.venue, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRegistrations,
            icon: const Icon(Icons.people_outline),
            label: const Text('View donor registrations'),
          ),
        ],
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.organisation),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load dashboard information.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
