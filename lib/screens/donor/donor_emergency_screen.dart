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

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  Future<_EmergencyData> loadData() async {
    final client = SupabaseService.client;
    if (client == null) return const _EmergencyData([], {}, false);
    final results = await Future.wait([
      EmergencyRepository(client).getMatchingDonorRequests(),
      EmergencyResponseRepository(client).getMyPendingRequestIds(),
      EmergencyResponseRepository(client).hasActiveDonationCommitment(),
    ]);
    return _EmergencyData(
      results[0] as List<EmergencyRequest>,
      results[1] as Set<String>,
      results[2] as bool,
    );
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
                final responded = value.pendingRequestIds.contains(request.id);
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
                                '${request.unitsNeeded} units requested',
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
                                  blockedByAnotherCommitment
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
    this.pendingRequestIds,
    this.hasActiveCommitment,
  );

  final List<EmergencyRequest> requests;
  final Set<String> pendingRequestIds;
  final bool hasActiveCommitment;
}
