import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/role_request_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/remote/system_admin_repository.dart';
import '../../models/role_request.dart';
import '../../widgets/notification_button.dart';
import '../../widgets/signed_in_identity_card.dart';
import '../statistics_screen.dart';
import 'feedback_inbox_screen.dart';
import 'manage_rewards_screen.dart';
import 'user_directory_screen.dart';

class SystemAdminDashboardScreen extends StatefulWidget {
  const SystemAdminDashboardScreen({super.key});

  @override
  State<SystemAdminDashboardScreen> createState() =>
      _SystemAdminDashboardScreenState();
}

class _SystemAdminDashboardScreenState
    extends State<SystemAdminDashboardScreen> {
  late Future<_SystemAdminData> data;
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  Future<_SystemAdminData> loadData() async {
    final client = SupabaseService.client;
    if (client == null) {
      return const _SystemAdminData(
        requests: [],
        counts: SystemUserCounts(
          donors: 0,
          admins: 0,
          hospitals: 0,
          systemAdmins: 0,
        ),
      );
    }
    final results = await Future.wait([
      RoleRequestRepository(client).getAll(),
      SystemAdminRepository(client).getUserCounts(),
    ]);
    return _SystemAdminData(
      requests: results[0] as List<RoleRequest>,
      counts: results[1] as SystemUserCounts,
    );
  }

  Future<void> refresh() async {
    final refreshed = loadData();
    setState(() {
      data = refreshed;
    });
    await refreshed;
  }

  Future<String?> requestRejectionReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Explain what information is missing or invalid.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> review(RoleRequest request, bool approve) async {
    final client = SupabaseService.client;
    if (client == null) return;
    final rejectionReason = approve ? null : await requestRejectionReason();
    if (!approve && rejectionReason == null) return;
    try {
      await RoleRequestRepository(client).review(
        requestId: request.id,
        approve: approve,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Access approved.' : 'Application rejected.'),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to review application: $error')),
      );
    }
  }

  Future<void> openDocument(String proofPath) async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      final url = await RoleRequestRepository(client).createProofUrl(proofPath);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No application can open this document.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open document: $error')),
      );
    }
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> openUsers(String title, Set<String> roles) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDirectoryScreen(title: title, roles: roles),
      ),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.systemAdminBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.systemAdminHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
        automaticallyImplyLeading: false,
        title: const Text('System Administration'),
        actions: const [
          StatisticsIconButton(useSystemAdminColors: true),
          NotificationButton(useSystemAdminColors: true),
        ],
      ),
      body: FutureBuilder<_SystemAdminData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Unable to load dashboard. Try again'),
              ),
            );
          }
          final value = snapshot.data!;
          final filtered = selectedStatus == 'all'
              ? value.requests
              : value.requests
                    .where((request) => request.status == selectedStatus)
                    .toList();
          final pending = value.requests
              .where((request) => request.status == 'pending')
              .length;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const SignedInIdentityCard(roleLabel: 'System administrator'),
                const SizedBox(height: 12),
                Text(
                  'Platform overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisExtent: 120,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _CountCard(
                      label: 'Donors',
                      value: value.counts.donors,
                      icon: Icons.people_outline,
                      onTap: () => openUsers('Donors', const {'donor'}),
                    ),
                    _CountCard(
                      label: 'Organisation admins',
                      value: value.counts.admins,
                      icon: Icons.event_available_outlined,
                      onTap: () =>
                          openUsers('Organisation admins', const {'admin'}),
                    ),
                    _CountCard(
                      label: 'Hospitals',
                      value: value.counts.hospitals,
                      icon: Icons.local_hospital_outlined,
                      onTap: () => openUsers('Hospitals', const {
                        'hospital',
                        'hospital_admin',
                      }),
                    ),
                    _CountCard(
                      label: 'Pending requests',
                      value: pending,
                      icon: Icons.pending_actions_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.redeem_outlined),
                    title: const Text('Manage redeem rewards'),
                    subtitle: const Text(
                      'Create rewards and manage images, icons, points and stock.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageRewardsScreen(),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('Feedback inbox'),
                    subtitle: const Text(
                      'Read feedback, reply and update its status.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FeedbackInboxScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Staff access applications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['all', 'pending', 'approved', 'rejected']
                      .map(
                        (status) => ChoiceChip(
                          label: Text(
                            '${status[0].toUpperCase()}${status.substring(1)}',
                          ),
                          selected: selectedStatus == status,
                          onSelected: (_) => setState(() {
                            selectedStatus = status;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Card(
                    child: ListTile(
                      title: Text('No $selectedStatus applications.'),
                    ),
                  )
                else
                  ...filtered.map(
                    (request) => _ApplicationCard(
                      request: request,
                      dateLabel: dateLabel,
                      onOpenDocument: openDocument,
                      onReview: review,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.request,
    required this.dateLabel,
    required this.onOpenDocument,
    required this.onReview,
  });

  final RoleRequest request;
  final String Function(DateTime) dateLabel;
  final Future<void> Function(String) onOpenDocument;
  final Future<void> Function(RoleRequest, bool) onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.requestedRole.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(request.status.toUpperCase())),
              ],
            ),
            Text(request.organisationName),
            Text('Position: ${request.staffPosition}'),
            Text('Submitted: ${dateLabel(request.createdAt)}'),
            if (request.reason case final reason?) ...[
              const SizedBox(height: 8),
              Text(reason),
            ],
            if (request.rejectionReason case final reason?) ...[
              const SizedBox(height: 8),
              Text('Rejection reason: $reason'),
            ],
            const SizedBox(height: 12),
            if (request.proofPaths.isNotEmpty)
              ...request.proofPaths.asMap().entries.map(
                (document) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenDocument(document.value),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(
                      request.proofNameAt(document.key),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
            else
              const Text('No supporting documents attached.'),
            if (request.status == 'pending') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onReview(request, false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onReview(request, true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemAdminData {
  const _SystemAdminData({required this.requests, required this.counts});

  final List<RoleRequest> requests;
  final SystemUserCounts counts;
}
