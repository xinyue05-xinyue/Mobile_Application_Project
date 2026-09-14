import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/emergency_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';

class CreateEmergencyScreen extends StatefulWidget {
  const CreateEmergencyScreen({super.key});

  @override
  State<CreateEmergencyScreen> createState() => _CreateEmergencyScreenState();
}

class _CreateEmergencyScreenState extends State<CreateEmergencyScreen> {
  static const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final formKey = GlobalKey<FormState>();
  String bloodType = 'O+';
  String urgency = 'urgent';
  DateTime? deadline;
  bool isSaving = false;
  bool savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    restoreDraft();
  }

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(
      userId,
      'emergency_request_draft',
    );
    if (!mounted || draft == null) return;
    setState(() {
      bloodType = draft['blood_type'] as String? ?? bloodType;
      urgency = draft['urgency'] as String? ?? urgency;
      deadline = DateTime.tryParse(
        draft['deadline'] as String? ?? '',
      )?.toLocal();
    });
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance
        .saveMap(userId, 'emergency_request_draft', {
          'blood_type': bloodType,
          'urgency': urgency,
          'deadline': deadline?.toUtc().toIso8601String(),
        });
  }

  @override
  void dispose() {
    if (!savedSuccessfully) saveDraft();
    super.dispose();
  }

  String deadlineLabel() {
    final value = deadline;
    if (value == null) return 'Select deadline';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  Future<void> chooseDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (time == null) return;
    setState(() {
      deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (deadline == null || !deadline!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a future deadline.')),
      );
      return;
    }
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => isSaving = true);
    try {
      await EmergencyRepository(
        client,
      ).create(bloodType: bloodType, urgency: urgency, deadline: deadline!);
      await LocalCacheService.instance.remove(
        client.auth.currentUser!.id,
        'emergency_request_draft',
      );
      savedSuccessfully = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency request created.')),
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.hospitalBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.hospitalHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.hospitalHeaderTitleStyle,
        title: const Text('Create emergency request'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              initialValue: bloodType,
              decoration: const InputDecoration(
                labelText: 'Required blood type',
              ),
              items: bloodTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => bloodType = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: urgency,
              decoration: const InputDecoration(labelText: 'Urgency'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: (value) => setState(() => urgency = value!),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              leading: const Icon(Icons.schedule_outlined),
              title: Text(deadlineLabel()),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: chooseDeadline,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSaving ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hospital,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.hospitalPalette[1],
                disabledForegroundColor: AppTheme.hospitalHeader,
              ),
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create request'),
            ),
          ],
        ),
      ),
    );
  }
}
