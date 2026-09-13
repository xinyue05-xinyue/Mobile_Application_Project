import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../data/remote/event_registration_repository.dart';
import '../data/remote/profile_repository.dart';
import '../data/remote/supabase_service.dart';
import '../data/repositories/data_sync_service.dart';
import '../models/donation_event.dart';
import '../models/donor_level.dart';
import '../models/profile_overview.dart';
import '../widgets/my_darah_brand.dart';
import '../widgets/notification_button.dart';
import 'donor/attendance_qr_screen.dart';
import 'donor/benefits_screen.dart';
import 'donor/donor_emergency_screen.dart';
import 'donor/history_screens.dart';
import 'statistics_screen.dart';

class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key, required this.onTabSelected});
  final ValueChanged<int> onTabSelected;

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  late Future<_HomeData> data = loadData();

  Future<_HomeData> loadData() async {
    final client = SupabaseService.client;
    if (client == null) return const _HomeData(hasError: true);
    ProfileOverview? overview;
    Map<String, String> statuses = const {};
    List<DonationEvent> events = const [];
    var hasError = false;
    try {
      final results = await Future.wait([
        ProfileRepository(client).getOverview(),
        EventRegistrationRepository(client).getMyRegistrationStatuses(),
        DataSyncService().loadEvents(),
      ]);
      overview = results[0] as ProfileOverview;
      statuses = results[1] as Map<String, String>;
      events = results[2] as List<DonationEvent>;
    } on Object {
      hasError = true;
      try {
        overview = await ProfileRepository(client).getOverview();
      } on Object catch (_) {}
    }
    final now = DateTime.now();
    final ids = statuses.entries
        .where((entry) => entry.value == 'registered')
        .map((entry) => entry.key)
        .toSet();
    final registered = events.where((event) => ids.contains(event.id)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    DonationEvent? active;
    DonationEvent? next;
    for (final event in registered) {
      if (!now.isBefore(event.startsAt) && now.isBefore(event.endsAt)) {
        active = event;
        break;
      }
      if (event.startsAt.isAfter(now)) next ??= event;
    }
    return _HomeData(
      overview: overview,
      activeEvent: active,
      nextEvent: next,
      donorId: client.auth.currentUser?.id,
      hasError: hasError,
    );
  }

  Future<void> refresh() async {
    final refreshed = loadData();
    setState(() {
      data = refreshed;
    });
    await refreshed;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.donorBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.donorHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.donorHeaderTitleStyle,
      automaticallyImplyLeading: false,
      title: const MyDarahWordmark(markSize: 32, onDark: true),
      actions: const [
        StatisticsIconButton(useDonorColors: true),
        NotificationButton(useDonorColors: true),
      ],
    ),
    body: FutureBuilder<_HomeData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: _HomeContent(
            data: snapshot.data ?? const _HomeData(hasError: true),
            onTabSelected: widget.onTabSelected,
          ),
        );
      },
    ),
  );
}

class _HomeData {
  const _HomeData({
    this.overview,
    this.activeEvent,
    this.nextEvent,
    this.donorId,
    this.hasError = false,
  });
  final ProfileOverview? overview;
  final DonationEvent? activeEvent;
  final DonationEvent? nextEvent;
  final String? donorId;
  final bool hasError;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.onTabSelected});
  final _HomeData data;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    final profile = overview?.profile;
    final donationCount = overview?.donations.length ?? 0;
    final points = overview?.rewardPoints ?? 0;
    final firstName = profile?.fullName.trim().split(RegExp(r'\s+')).first;
    final nextEligible = profile?.nextEligibleDate;
    final eligible =
        nextEligible == null || !nextEligible.isAfter(DateTime.now());
    final hasBloodType = profile?.bloodType?.isNotEmpty == true;

    void donations() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DonationHistoryScreen(donations: overview?.donations ?? const []),
      ),
    );
    void rewards() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RewardHistoryScreen(rewards: overview?.rewards ?? const []),
      ),
    );
    void benefits() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DonorBenefitsScreen(donationCount: donationCount, points: points),
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          '${_greeting()}, ${firstName?.isNotEmpty == true ? firstName : 'Donor'}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          data.hasError
              ? 'Some information is temporarily unavailable.'
              : 'Your next chance to help starts here.',
        ),
        const SizedBox(height: 18),
        _EligibilityCard(
          hasBloodType: hasBloodType,
          bloodType: profile?.bloodType,
          eligible: eligible,
          nextEligible: nextEligible,
          onCompleteProfile: () => onTabSelected(3),
        ),
        if (data.activeEvent != null && data.donorId != null) ...[
          const SizedBox(height: 14),
          _ActiveEventCard(
            event: data.activeEvent!,
            onQr: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DonorAttendanceQrScreen(
                  event: data.activeEvent!,
                  donorId: data.donorId!,
                ),
              ),
            ),
          ),
        ] else if (data.nextEvent != null) ...[
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              onTap: () => onTabSelected(2),
              leading: const CircleAvatar(child: Icon(Icons.event_available)),
              title: const Text('Your next registered event'),
              subtitle: Text(
                '${data.nextEvent!.title}\n${data.nextEvent!.venue}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Donations',
                value: '$donationCount',
                icon: Icons.bloodtype_outlined,
                onTap: donations,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                label: 'Points',
                value: '$points',
                icon: Icons.stars_outlined,
                onTap: rewards,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                label: 'Level',
                value: DonorLevel.name(donationCount, short: true),
                icon: Icons.workspace_premium_outlined,
                onTap: benefits,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DonorEmergencyScreen()),
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFE8E5),
              child: Icon(Icons.emergency_outlined, color: Color(0xFFD74435)),
            ),
            title: const Text('Emergency blood requests'),
            subtitle: const Text('See urgent requests matching your profile'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 18),
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: HomeMenuItem(
                icon: Icons.location_on_outlined,
                title: 'Find centre',
                onTap: () => onTabSelected(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HomeMenuItem(
                icon: Icons.calendar_month_outlined,
                title: 'Browse events',
                onTap: () => onTabSelected(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HomeMenuItem(
                icon: Icons.history,
                title: 'My donations',
                onTap: donations,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({
    required this.hasBloodType,
    required this.bloodType,
    required this.eligible,
    required this.nextEligible,
    required this.onCompleteProfile,
  });
  final bool hasBloodType;
  final String? bloodType;
  final bool eligible;
  final DateTime? nextEligible;
  final VoidCallback onCompleteProfile;

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final color = !hasBloodType
        ? const Color(0xFF667085)
        : eligible
        ? const Color(0xFF3FAE63)
        : const Color(0xFFE9AA2F);
    final title = !hasBloodType
        ? 'Complete your donor profile'
        : eligible
        ? 'You are eligible to donate'
        : 'Recovery period in progress';
    final subtitle = !hasBloodType
        ? 'Add your blood type to receive matching alerts.'
        : eligible
        ? 'Blood type $bloodType • Ready for a new donation'
        : 'Blood type $bloodType • Eligible from ${_date(nextEligible!)}';
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      child: InkWell(
        onTap: hasBloodType ? null : onCompleteProfile,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(subtitle, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  !hasBloodType
                      ? Icons.person_add_alt_1
                      : eligible
                      ? Icons.check_circle_outline
                      : Icons.hourglass_bottom,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveEventCard extends StatelessWidget {
  const _ActiveEventCard({required this.event, required this.onQr});
  final DonationEvent event;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) => Card(
    color: AppTheme.donorPalette[0],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radio_button_checked, color: AppTheme.donor),
              SizedBox(width: 8),
              Text(
                'Happening now',
                style: TextStyle(
                  color: AppTheme.donor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(event.venue, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onQr,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Show my attendance QR'),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class HomeMenuItem extends StatelessWidget {
  const HomeMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
