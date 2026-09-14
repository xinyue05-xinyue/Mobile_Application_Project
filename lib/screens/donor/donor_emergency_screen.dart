import 'package:flutter/material.dart';
import '../../widgets/institution_details_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/emergency_repository.dart';
import '../../data/remote/emergency_response_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/emergency_request.dart';
import 'emergency_attendance_qr_screen.dart';

class DonorEmergencyScreen extends StatefulWidget {
  const DonorEmergencyScreen({super.key});

  @override
  State<DonorEmergencyScreen> createState() => _DonorEmergencyScreenState();
}

class _DonorEmergencyScreenState extends State<DonorEmergencyScreen> {
  late Future<_EmergencyData> data;
  String? submittingRequestId;
  String? cancellingRequestId;

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  Future<_EmergencyData> loadData() async {
    final client = SupabaseService.client;
    if (client == null) return const _EmergencyData([], {}, false);
    final responseRepository = EmergencyResponseRepository(client);
    final emergencyRepository = EmergencyRepository(client);
    final responseStatuses = await responseRepository.getMyResponseStatuses();
    final results = await Future.wait([
      emergencyRepository.getMatchingDonorRequests(),
      emergencyRepository.getRequestsByIds(responseStatuses.keys.toSet()),
      responseRepository.hasActiveDonationCommitment(),
    ]);
    final requests = <String, EmergencyRequest>{
      for (final request in results[0] as List<EmergencyRequest>)
        request.id: request,
      for (final request in results[1] as List<EmergencyRequest>)
        request.id: request,
    }.values.toList()..sort((a, b) => a.deadline.compareTo(b.deadline));
    return _EmergencyData(requests, responseStatuses, results[2] as bool);
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  Future<void> respond(EmergencyRequest request) async {
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => submittingRequestId = request.id);
    try {
      await EmergencyResponseRepository(client).respond(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Response sent. The hospital can now verify it.'),
        ),
      );
      setState(() {
        data = loadData();
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => submittingRequestId = null);
    }
  }

  Future<void> cancel(EmergencyRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.donorBackground,
        title: const Text('Cancel emergency response?'),
        content: const Text(
          'After cancelling, you can register for another available donation event or emergency request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep response'),
          ),
          FilledButton(
            style: AppTheme.donorPrimaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel response'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => cancellingRequestId = request.id);
    try {
      await EmergencyResponseRepository(client).cancel(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency response cancelled.')),
      );
      setState(() => data = loadData());
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => cancellingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Emergency blood requests'),
      ),
      body: FutureBuilder<_EmergencyData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load alerts: ${snapshot.error}'),
            );
          }
          final value = snapshot.data ?? const _EmergencyData([], {}, false);
          if (value.requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No active requests match your blood type and eligibility information.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              data = loadData();
            }),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: value.requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = value.requests[index];
                final responseStatus = value.responseStatuses[request.id];
                final responded = responseStatus == 'pending';
                final expired =
                    responseStatus == 'expired' ||
                    request.status != 'active' ||
                    !request.deadline.isAfter(DateTime.now());
                final completed = responseStatus == 'completed';
                final blockedByAnotherCommitment =
                    value.hasActiveCommitment && !responded;
                return Card(
                  color: request.urgency == 'critical'
                      ? Theme.of(context).colorScheme.errorContainer
                      : null,
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
                              child: Text(
                                '${request.bloodType} emergency request',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Urgency: ${request.urgency.toUpperCase()}'),
                        InstitutionDetailsTile(
                          ownerId: request.hospitalId,
                          label: 'Requested by',
                          useDonorColors: true,
                        ),
                        Text('Respond before: ${dateLabel(request.deadline)}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Complete the hospital eligibility screening before donating.',
                        ),
                        if (blockedByAnotherCommitment) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Complete or wait for your current donation commitment to end before responding.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              submittingRequestId != null ||
                                  blockedByAnotherCommitment ||
                                  expired ||
                                  completed
                              ? null
                              : responded
                              ? () {
                                  final donorId = SupabaseService
                                      .client
                                      ?.auth
                                      .currentUser
                                      ?.id;
                                  if (donorId == null) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EmergencyAttendanceQrScreen(
                                            request: request,
                                            donorId: donorId,
                                          ),
                                    ),
                                  );
                                }
                              : () => respond(request),
                          icon: Icon(
                            responded
                                ? Icons.qr_code_2
                                : Icons.volunteer_activism,
                          ),
                          label: Text(
                            responded
                                ? 'Show emergency donation QR'
                                : 'I can donate',
                          ),
                        ),
                        if (responded) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: cancellingRequestId == null
                                ? () => cancel(request)
                                : null,
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(
                              cancellingRequestId == request.id
                                  ? 'Cancelling...'
                                  : 'Cancel response',
                            ),
                          ),
                        ],
                        if (expired) ...[
                          const SizedBox(height: 8),
                          const Chip(label: Text('Expired')),
                        ],
                        if (completed) ...[
                          const SizedBox(height: 8),
                          const Chip(label: Text('Completed')),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmergencyData {
  const _EmergencyData(
    this.requests,
    this.responseStatuses,
    this.hasActiveCommitment,
  );

  final List<EmergencyRequest> requests;
  final Map<String, String> responseStatuses;
  final bool hasActiveCommitment;
}
