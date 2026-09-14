import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/event_registration_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donation_event.dart';
import '../../models/event_registration.dart';
import '../../models/attendance_qr.dart';

class QrAttendanceScannerScreen extends StatefulWidget {
  const QrAttendanceScannerScreen({super.key, this.event});

  final DonationEvent? event;

  @override
  State<QrAttendanceScannerScreen> createState() =>
      _QrAttendanceScannerScreenState();
}

class _QrAttendanceScannerScreenState extends State<QrAttendanceScannerScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool processing = false;
  int verifiedCount = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String dateLabel(DateTime? date) {
    if (date == null) return 'Eligible now';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<DonationEvent> resolveEvent(
    AttendanceQrPayload payload,
    SupabaseClient client,
  ) async {
    if (widget.event != null) {
      if (payload.eventId != widget.event!.id.toLowerCase()) {
        throw const FormatException(
          'This QR belongs to a different event. Use the centre scanner to detect its event automatically.',
        );
      }
      return widget.event!;
    }

    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final row = await client
        .from('donation_events')
        .select(
          'id, title, venue, starts_at, ends_at, status, description, '
          'latitude, longitude, image_path, created_by, publish_at',
        )
        .eq('id', payload.eventId)
        .eq('created_by', user.id)
        .maybeSingle();
    if (row == null) {
      throw const FormatException(
        'This QR is for an event that does not belong to your organisation.',
      );
    }
    final event = DonationEvent.fromMap(row);
    if (event.status == 'cancelled') {
      throw const FormatException('This event has been cancelled.');
    }
    if (event.status != 'in_progress') {
      throw FormatException(
        'Attendance for ${event.title} can only be verified while the event is in progress.',
      );
    }
    return event;
  }

  Future<bool> confirmDonor(
    DonationEvent event,
    EventRegistration registration,
  ) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm completed donation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(registration.bloodType ?? '?'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    registration.donorName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Detected event'),
                    subtitle: Text('${event.title}\n${event.venue}'),
                    isThreeLine: true,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bloodtype_outlined),
                    title: const Text('Blood type'),
                    subtitle: Text(registration.bloodType ?? 'Not set'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Contact phone'),
                    subtitle: Text(registration.phone ?? 'Not set'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Eligibility'),
                    subtitle: Text(dateLabel(registration.nextEligibleDate)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Confirm donation'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> detected(BarcodeCapture capture) async {
    if (!mounted || processing || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    setState(() => processing = true);
    try {
      await controller.stop();
      if (!mounted) return;
      final payload = AttendanceQr.parse(value);
      final client = SupabaseService.client;
      if (client == null) {
        await showError('Please log in again.');
        return;
      }
      final event = await resolveEvent(payload, client);
      final donorId = payload.donorId;
      final repository = EventRegistrationRepository(client);
      final registration = await repository.getForEventAndDonor(
        eventId: event.id,
        donorId: donorId,
      );
      if (!mounted) return;
      if (registration == null) {
        await showError('This donor is not registered for this event.');
      } else if (registration.status == 'attended') {
        await showError('${registration.donorName} is already verified.');
      } else if (registration.status != 'registered') {
        await showError('This registration is ${registration.status}.');
      } else if (await confirmDonor(event, registration)) {
        if (!mounted) return;
        await repository.verifyQr(eventId: event.id, donorId: donorId);
        verifiedCount++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${registration.donorName} verified for ${event.title}. 100 points awarded and eligibility set three months later.',
              ),
            ),
          );
        }
      }
    } on FormatException catch (error) {
      await showError(error.message);
    } on PostgrestException catch (error) {
      await showError(error.message);
    } catch (_) {
      await showError(
        'Unable to complete verification. Check your connection, then check the registration status before trying again. You can also return to the list and use Verify.',
      );
    } finally {
      await resumeScanning();
    }
  }

  Future<void> showError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR not verified'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }

  Future<void> resumeScanning() async {
    if (!mounted) return;
    try {
      await controller.start();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera could not restart. Return to the donor list to verify manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.organisationBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.organisationHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.organisationHeaderTitleStyle,
        title: const Text('Scan donor QR'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, verifiedCount > 0),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: detected,
            errorBuilder: (context, error) => ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission is denied. Allow camera access for MyDarah in your device settings, or verify manually.'
                            : 'Camera is unavailable. You can still verify the donor manually.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, verifiedCount > 0),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to donor list'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.black87,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      processing
                          ? 'Checking donor…'
                          : 'Scan each donor after the blood donation is completed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$verifiedCount verified in this session',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
