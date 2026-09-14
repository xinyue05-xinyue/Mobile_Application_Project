import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../widgets/profile_actions.dart';

import '../../data/remote/profile_repository.dart';
import '../../data/remote/role_request_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/profile_overview.dart';
import '../../models/donor_level.dart';
import '../../models/role_request.dart';
import 'edit_profile_screen.dart';
import 'benefits_screen.dart';
import 'history_screens.dart';
import 'role_application_screen.dart';
import 'reward_store_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<ProfileOverview>? overview;
  Future<List<RoleRequest>>? requests;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final client = SupabaseService.client;
    overview = client == null ? null : ProfileRepository(client).getOverview();
    requests = client == null
        ? Future.value(const [])
        : RoleRequestRepository(client).getMine();
  }

  String dateLabel(DateTime? value) {
    if (value == null) return 'Not available';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> editProfile(ProfileOverview value) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: value.profile),
      ),
    );
    if (updated == true) setState(refresh);
  }

  Future<void> openApplication() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RoleApplicationScreen()),
    );
    if (submitted == true) setState(refresh);
  }

  Future<void> openRewards() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardStoreScreen()),
    );
    if (mounted) setState(refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        automaticallyImplyLeading: false,
        title: const Text('My Profile'),
        actions: const [ProfileLogoutButton()],
      ),
      body: overview == null
          ? const Center(child: Text('Profile requires a Supabase login.'))
          : FutureBuilder<ProfileOverview>(
              future: overview,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Unable to load profile: ${snapshot.error}'),
                    ),
                  );
                }
                final value = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: const Icon(Icons.person, size: 34),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value.profile.fullName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Text(
                                    SupabaseService
                                            .client
                                            ?.auth
                                            .currentUser
                                            ?.email ??
                                        '',
                                  ),
                                  Text(
                                    'Blood type: ${value.profile.bloodType ?? 'Not set'}',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => editProfile(value),
                              tooltip: 'Edit profile',
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Donations',
                            value: '${value.donations.length}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Points',
                            value: '${value.rewardPoints}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Next eligible',
                            value: value.profile.nextEligibleDate == null
                                ? 'Not set'
                                : dateLabel(value.profile.nextEligibleDate),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RewardProgressCard(
                      donationCount: value.donations.length,
                      onBenefits: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DonorBenefitsScreen(
                            donationCount: value.donations.length,
                            points: value.rewardPoints,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Donation history'),
                            subtitle: Text(
                              '${value.donations.length} verified donation${value.donations.length == 1 ? '' : 's'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DonationHistoryScreen(
                                  donations: value.donations,
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.stars_outlined),
                            title: const Text('Reward history'),
                            subtitle: Text(
                              '${value.rewards.length} transaction${value.rewards.length == 1 ? '' : 's'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RewardHistoryScreen(rewards: value.rewards),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.redeem_outlined),
                            title: const Text('Browse rewards'),
                            subtitle: Text(
                              '${value.rewardPoints} points available to redeem',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: openRewards,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Staff access',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: AppTheme.donorMutedOutlinedButtonStyle,
                      onPressed: openApplication,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Apply for admin or hospital access'),
                    ),
                    const SizedBox(height: 8),
                    _RoleRequests(requestFuture: requests),
                    const SizedBox(height: 24),
                    const ProfileActions(useDonorColors: true),
                  ],
                );
              },
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RewardProgressCard extends StatelessWidget {
  const _RewardProgressCard({
    required this.donationCount,
    required this.onBenefits,
  });

  final int donationCount;
  final VoidCallback onBenefits;

  @override
  Widget build(BuildContext context) {
    final target = DonorLevel.nextTarget(donationCount);
    final remaining = target == null ? 0 : target - donationCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DonorLevel.name(donationCount),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('$donationCount verified donations'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: DonorLevel.progress(donationCount),
                minHeight: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              target == null
                  ? 'Highest recognition level reached.'
                  : '$remaining more verified donation${remaining == 1 ? '' : 's'} to ${DonorLevel.name(target)}.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: AppTheme.donorMutedOutlinedButtonStyle,
                onPressed: onBenefits,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('View my benefits & level'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRequests extends StatelessWidget {
  const _RoleRequests({required this.requestFuture});

  final Future<List<RoleRequest>>? requestFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoleRequest>>(
      future: requestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const Text('No access applications.');
        return Column(
          children: items
              .map(
                (request) => Card(
                  child: ListTile(
                    title: Text(request.requestedRole.label),
                    subtitle: Text(request.organisationName),
                    trailing: Text(_roleRequestStatus(request.status)),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

String _roleRequestStatus(String status) => switch (status) {
  'approved' => 'APPROVED',
  'rejected' => 'REJECTED',
  'removed' => 'REMOVED',
  _ => 'PENDING',
};
