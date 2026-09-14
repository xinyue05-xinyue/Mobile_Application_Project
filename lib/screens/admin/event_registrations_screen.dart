import 'package:flutter/material.dart';
import '../../widgets/event_schedule.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/event_registration_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donation_event.dart';
import '../../models/event_registration.dart';
import 'qr_attendance_scanner_screen.dart';

class EventRegistrationsScreen extends StatefulWidget {
  const EventRegistrationsScreen({super.key, required this.event});

  final DonationEvent event;

  @override
  State<EventRegistrationsScreen> createState() =>
      _EventRegistrationsScreenState();
}

class _EventRegistrationsScreenState extends State<EventRegistrationsScreen> {
  late Future<List<EventRegistration>> registrations;
  bool verifying = false;

  Future<void> verifyManually(EventRegistration registration) async {
    if (verifying || !canVerify || registration.status != 'registered') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm completed donation'),
        content: Text(
          '${registration.donorName}\nBlood type: ${registration.bloodType ?? "Not set"}\n\nConfirm the donor’s identity and that blood donation is complete. This awards points and updates eligibility; attendance alone is not enough.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm donation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => verifying = true);
    try {
      final client = SupabaseService.client;
      if (client == null) throw StateError('Please log in again.');
      await EventRegistrationRepository(
        client,
      ).verifyQr(eventId: widget.event.id, donorId: registration.donorId);
      if (!mounted) return;
      setState(() {
        registrations = loadRegistrations();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation verified. Points and eligibility updated.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to verify donation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  void initState() {
    super.initState();
    registrations = loadRegistrations();
  }

  Future<List<EventRegistration>> loadRegistrations() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return EventRegistrationRepository(client).getForEvent(widget.event.id);
  }

  Future<void> scanAttendance() async {
    if (!canVerify) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(verificationMessage)));
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrAttendanceScannerScreen(event: widget.event),
      ),
    );
    if (mounted) {
      setState(() {
        registrations = loadRegistrations();
      });
    }
  }

  bool get canVerify => widget.event.status == 'in_progress';

  String get verificationMessage {
    if (widget.event.status == 'cancelled') {
      return 'Attendance cannot be verified for a cancelled event.';
    }
    if (widget.event.status == 'ended') {
      return 'Attendance can no longer be verified because this event has ended.';
    }
    return 'Attendance can only be verified while the event is in progress.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.organisationBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.organisationHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.organisationHeaderTitleStyle,
        title: Text(widget.event.title),
      ),
      floatingActionButton: canVerify
          ? FloatingActionButton.extended(
              onPressed: scanAttendance,
              backgroundColor: AppTheme.organisation,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan donor QR'),
            )
          : null,
      body: FutureBuilder<List<EventRegistration>>(
        future: registrations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load registrations: ${snapshot.error}'),
            );
          }
          final items = snapshot.data ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  color: AppTheme.organisationPalette[1],
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      eventSchedule(widget.event.startsAt, widget.event.endsAt),
                    ),
                    subtitle: Text(
                      !canVerify
                          ? verificationMessage
                          : items.isEmpty
                          ? 'No donor registrations yet.'
                          : 'Verify only after the donor has completed donation.',
                    ),
                  ),
                );
              }
              final registration = items[index - 1];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    child: Text(registration.bloodType ?? '?'),
                  ),
                  title: Text(registration.donorName),
                  subtitle: Text('Status: ${registration.status}'),
                  trailing: registration.status == 'attended'
                      ? const Icon(Icons.verified, color: Colors.green)
                      : registration.status == 'registered'
                      ? FilledButton(
                          onPressed: canVerify && !verifying
                              ? () => verifyManually(registration)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.organisation,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.organisationPalette[1],
                            disabledForegroundColor:
                                AppTheme.organisationHeader,
                          ),
                          child: const Text('Verify'),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
