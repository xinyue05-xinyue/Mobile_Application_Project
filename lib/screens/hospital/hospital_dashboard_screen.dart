import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/emergency_repository.dart';
import '../../data/remote/hospital_dashboard_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/emergency_request.dart';
import '../../widgets/notification_button.dart';
import '../../widgets/signed_in_identity_card.dart';
import '../statistics_screen.dart';
import 'create_emergency_screen.dart';
import 'emergency_responses_screen.dart';

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  late Future<HospitalDashboardData> data;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  Future<HospitalDashboardData> loadData() {
    final client = SupabaseService.client;
    if (client == null) {
      return Future.value(
        const HospitalDashboardData(
          requests: [],
          responseCounts: {},
          totalResponses: 0,
          completedResponses: 0,
        ),
      );
    }
    return HospitalDashboardRepository(client).getData();
  }

  Future<void> refresh() async {
    final refreshed = loadData();
    setState(() {
      data = refreshed;
    });
    await refreshed;
  }

  bool isExpired(EmergencyRequest request) {
    return request.status == 'active' &&
        !request.deadline.isAfter(DateTime.now());
  }

  String effectiveStatus(EmergencyRequest request) {
    return isExpired(request) ? 'expired' : request.status;
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  Future<void> createRequest() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateEmergencyScreen()),
    );
    if (created == true && mounted) await refresh();
  }

  Future<bool> confirmStatus(EmergencyRequest request, String status) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              status == 'fulfilled' ? 'Fulfil request?' : 'Cancel request?',
            ),
            content: Text(
              status == 'fulfilled'
                  ? 'Confirm that the blood requirement has been fulfilled.'
                  : 'Donors will no longer be able to respond to this request.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  status == 'fulfilled' ? 'Fulfil' : 'Cancel request',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> updateStatus(EmergencyRequest request, String status) async {
    if (!await confirmStatus(request, status)) return;
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await EmergencyRepository(client).updateStatus(request.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request marked as $status.')));
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update request: $error')),
      );
    }
  }

  Future<void> openResponses(EmergencyRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyResponsesScreen(request: request),
      ),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hospital Emergency'),
        actions: const [
          StatisticsIconButton(useHospitalColors: true),
          NotificationButton(useHospitalColors: true),
        ],
      ),
      body: FutureBuilder<HospitalDashboardData>(
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
          final activeCount = value.requests
              .where((request) => effectiveStatus(request) == 'active')
              .length;
          final expiredCount = value.requests
              .where((request) => effectiveStatus(request) == 'expired')
              .length;
          final items = selectedFilter == 'all'
              ? value.requests
              : value.requests
                    .where(
                      (request) => effectiveStatus(request) == selectedFilter,
                    )
                    .toList();

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const SignedInIdentityCard(
                  roleLabel: 'Hospital staff',
                  useInstitutionProfile: true,
                ),
                const SizedBox(height: 16),
                _HospitalHero(
                  activeCount: activeCount,
                  responseCount: value.totalResponses,
                  onCreate: createRequest,
                ),
                const SizedBox(height: 18),
                Text(
                  'Today at a glance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisExtent: 120,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _MetricCard(
                      label: 'Active requests',
                      value: activeCount,
                      icon: Icons.emergency_outlined,
                    ),
                    _MetricCard(
                      label: 'Expired requests',
                      value: expiredCount,
                      icon: Icons.timer_off_outlined,
                    ),
                    _MetricCard(
                      label: 'Donor responses',
                      value: value.totalResponses,
                      icon: Icons.people_outline,
                    ),
                    _MetricCard(
                      label: 'Completed donations',
                      value: value.completedResponses,
                      icon: Icons.bloodtype_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'active', 'fulfilled', 'cancelled', 'expired']
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                '${filter[0].toUpperCase()}${filter.substring(1)}',
                              ),
                              selected: selectedFilter == filter,
                              onSelected: (_) => setState(() {
                                selectedFilter = filter;
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Card(
                    child: ListTile(
                      title: Text('No $selectedFilter emergency requests.'),
                    ),
                  )
                else
                  ...items.map(
                    (request) => _RequestCard(
                      request: request,
                      status: effectiveStatus(request),
                      responseCount: value.responseCounts[request.id] ?? 0,
                      dateLabel: dateLabel,
                      onOpenResponses: openResponses,
                      onUpdateStatus: updateStatus,
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

class _HospitalHero extends StatelessWidget {
  const _HospitalHero({
    required this.activeCount,
    required this.responseCount,
    required this.onCreate,
  });

  final int activeCount;
  final int responseCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.hospital, Color(0xFFB72E68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.hospital.withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Emergency response centre',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$activeCount active request${activeCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$responseCount donor response${responseCount == 1 ? '' : 's'} received',
            style: TextStyle(color: Colors.white.withValues(alpha: .86)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB72E68),
            ),
            icon: const Icon(Icons.add_alert_rounded),
            label: const Text('Create emergency request'),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.status,
    required this.responseCount,
    required this.dateLabel,
    required this.onOpenResponses,
    required this.onUpdateStatus,
  });

  final EmergencyRequest request;
  final String status;
  final int responseCount;
  final String Function(DateTime) dateLabel;
  final Future<void> Function(EmergencyRequest) onOpenResponses;
  final Future<void> Function(EmergencyRequest, String) onUpdateStatus;

  String timeRemaining() {
    final difference = request.deadline.difference(DateTime.now());
    if (difference.isNegative) return 'Deadline passed';
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours.remainder(24)}h remaining';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m remaining';
    }
    return '${difference.inMinutes} minutes remaining';
  }

  Future<void> showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.hospitalBackground,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${request.bloodType} emergency request',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Status', value: status.toUpperCase()),
              _DetailRow(
                label: 'Urgency',
                value: request.urgency.toUpperCase(),
              ),
              _DetailRow(
                label: 'Blood type required',
                value: request.bloodType,
              ),
              _DetailRow(label: 'Created', value: dateLabel(request.createdAt)),
              _DetailRow(label: 'Deadline', value: dateLabel(request.deadline)),
              _DetailRow(label: 'Time status', value: timeRemaining()),
              _DetailRow(label: 'Donor responses', value: '$responseCount'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.hospital,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenResponses(request);
                  },
                  icon: const Icon(Icons.people_outline),
                  label: const Text('View donor responses'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                CircleAvatar(child: Text(request.bloodType)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.bloodType} emergency request',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${request.urgency.toUpperCase()} • ${status.toUpperCase()}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Deadline: ${dateLabel(request.deadline)}'),
            Text(
              timeRemaining(),
              style: TextStyle(
                color: status == 'active'
                    ? Theme.of(context).colorScheme.primary
                    : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$responseCount donor response${responseCount == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showDetails(context),
              icon: const Icon(Icons.info_outline),
              label: const Text('View request details'),
            ),
            if (status == 'active') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUpdateStatus(request, 'cancelled'),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onUpdateStatus(request, 'fulfilled'),
                      child: const Text('Fulfilled'),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  Text('$value', style: Theme.of(context).textTheme.titleLarge),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
