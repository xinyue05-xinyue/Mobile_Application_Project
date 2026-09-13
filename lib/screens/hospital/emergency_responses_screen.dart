import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/emergency_response_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/emergency_request.dart';
import '../../models/emergency_response.dart';
import 'emergency_qr_scanner_screen.dart';

class EmergencyResponsesScreen extends StatefulWidget {
  const EmergencyResponsesScreen({super.key, required this.request});

  final EmergencyRequest request;

  @override
  State<EmergencyResponsesScreen> createState() =>
      _EmergencyResponsesScreenState();
}

class _EmergencyResponsesScreenState extends State<EmergencyResponsesScreen> {
  late Future<List<EmergencyResponse>> responses;
  String? verifyingResponseId;

  @override
  void initState() {
    super.initState();
    responses = loadResponses();
  }

  Future<List<EmergencyResponse>> loadResponses() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return EmergencyResponseRepository(client).getForRequest(widget.request.id);
  }

  Future<void> verify(EmergencyResponse response) async {
    final today = DateTime.now();
    final month = today.month + 3;
    final year = today.year + (month - 1) ~/ 12;
    final normalisedMonth = (month - 1) % 12 + 1;
    final lastDay = DateTime(year, normalisedMonth + 1, 0).day;
    final nextDate = DateTime(
      year,
      normalisedMonth,
      today.day.clamp(1, lastDay),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify completed donation?'),
        content: Text(
          'This creates a verified donation record, awards 150 points, and sets the next eligible date to ${dateLabel(nextDate)} (three months from today). This action cannot be repeated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => verifyingResponseId = response.id);
    try {
      await EmergencyResponseRepository(
        client,
      ).verifyDonation(responseId: response.id, nextEligibleDate: nextDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation verified and 150 points awarded.'),
        ),
      );
      setState(() {
        responses = loadResponses();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to verify donation: $error')),
      );
    } finally {
      if (mounted) setState(() => verifyingResponseId = null);
    }
  }

  String dateLabel(DateTime? value) {
    if (value == null) return 'Eligible now';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> showDonor(EmergencyResponse response) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.hospitalBackground,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 34, child: Text(response.bloodType ?? '?')),
              const SizedBox(height: 12),
              Text(
                response.donorName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.bloodtype_outlined),
                title: const Text('Blood type'),
                subtitle: Text(response.bloodType ?? 'Not set'),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Contact phone'),
                subtitle: Text(response.phone ?? 'Not set'),
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Donation eligibility'),
                subtitle: Text(dateLabel(response.nextEligibleDate)),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Response status'),
                subtitle: Text(response.status.toUpperCase()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.hospitalBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.hospitalHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.hospitalHeaderTitleStyle,
        title: const Text('Donor responses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.hospital,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmergencyQrScannerScreen(request: widget.request),
            ),
          );
          if (mounted) {
            setState(() {
              responses = loadResponses();
            });
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan donor QR'),
      ),
      body: FutureBuilder<List<EmergencyResponse>>(
        future: responses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load responses: ${snapshot.error}'),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No donor responses yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              responses = loadResponses();
            }),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final response = items[index];
                return Card(
                  child: ListTile(
                    onTap: () => showDonor(response),
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Text(response.bloodType ?? '?'),
                    ),
                    title: Text(response.donorName),
                    subtitle: Text('Status: ${response.status}'),
                    trailing: response.status != 'pending'
                        ? const Icon(Icons.verified, color: Colors.green)
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.hospital,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppTheme.hospitalPalette[1],
                              disabledForegroundColor: AppTheme.hospitalHeader,
                            ),
                            onPressed: verifyingResponseId == null
                                ? () => verify(response)
                                : null,
                            child: verifyingResponseId == response.id
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verify'),
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
