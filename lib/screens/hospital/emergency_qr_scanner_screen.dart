import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/emergency_repository.dart';
import '../../data/remote/emergency_response_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/emergency_attendance_qr.dart';
import '../../models/emergency_request.dart';
import '../../models/emergency_response.dart';

class EmergencyQrScannerScreen extends StatefulWidget {
  const EmergencyQrScannerScreen({super.key, this.request});
  final EmergencyRequest? request;

  @override
  State<EmergencyQrScannerScreen> createState() =>
      _EmergencyQrScannerScreenState();
}

class _EmergencyQrScannerScreenState extends State<EmergencyQrScannerScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool processing = false;
  int verifiedCount = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  DateTime threeMonthsFrom(DateTime date) {
    final targetMonth = date.month + 3;
    final targetYear = date.year + (targetMonth - 1) ~/ 12;
    final month = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(targetYear, month + 1, 0).day;
    return DateTime(targetYear, month, date.day.clamp(1, lastDay));
  }

  Future<void> detect(BarcodeCapture capture) async {
    if (processing) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null) return;
    final qr = EmergencyAttendanceQr.tryParse(raw);
    if (qr == null) {
      _message('This is not a valid MyDarah emergency donation QR.');
      return;
    }
    if (widget.request != null && qr.requestId != widget.request!.id) {
      _message('This QR does not belong to this emergency request.');
      return;
    }
    setState(() => processing = true);
    await controller.stop();
    try {
      final client = SupabaseService.client;
      if (client == null) throw StateError('Please log in again.');
      final request =
          widget.request ??
          await EmergencyRepository(client).getOwnedRequest(qr.requestId);
      if (request == null) {
        throw StateError(
          'This emergency request does not belong to your hospital.',
        );
      }
      final repository = EmergencyResponseRepository(client);
      final response = await repository.getForRequestAndDonor(
        requestId: qr.requestId,
        donorId: qr.donorId,
      );
      if (response == null) {
        throw StateError('This donor has not responded to the request.');
      }
      if (response.status != 'pending') {
        throw StateError('This donation has already been processed.');
      }
      final confirmed = await _confirm(request, response);
      if (confirmed != true) return;
      await repository.verifyDonation(
        responseId: response.id,
        nextEligibleDate: threeMonthsFrom(DateTime.now()),
      );
      verifiedCount++;
      _message(
        'Attendance verified. 150 points awarded and eligibility updated.',
      );
    } on Object catch (error) {
      _message('Unable to verify: $error');
    } finally {
      if (mounted) {
        setState(() => processing = false);
        await controller.start();
      }
    }
  }

  Future<bool?> _confirm(
    EmergencyRequest request,
    EmergencyResponse response,
  ) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.hospitalBackground,
      surfaceTintColor: Colors.transparent,
      title: const Text('Confirm completed donation'),
      content: Text(
        'Emergency request: ${request.bloodType}\n'
        'Donor: ${response.donorName}\n'
        'Blood type: ${response.bloodType ?? 'Not set'}\n\n'
        'Confirm the donor identity and completed blood collection. '
        'This marks attendance, awards 150 points, and sets the next '
        'eligible date to three months from today.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.hospital,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Verify donation'),
        ),
      ],
    ),
  );

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.hospitalBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.hospitalHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.hospitalHeaderTitleStyle,
      title: const Text('Scan emergency donor QR'),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: controller, onDetect: detect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            color: Colors.black87,
            child: Text(
              processing
                  ? 'Checking donor…'
                  : 'Scan after donation is complete\n$verifiedCount verified this session',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
