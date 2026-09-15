import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/profile_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donor_profile.dart';
import '../../models/malaysian_state.dart';
import '../../utils/profile_validation.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final DonorProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  String? bloodType;
  String? selectedState;
  DateTime? dateOfBirth;
  late bool notificationsEnabled;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profile.fullName);
    phoneController = TextEditingController(text: widget.profile.phone);
    bloodType = widget.profile.bloodType;
    selectedState = widget.profile.state;
    dateOfBirth = widget.profile.dateOfBirth;
    notificationsEnabled = widget.profile.notificationsEnabled;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String dateLabel(DateTime? value) {
    if (value == null) return 'Select date of birth';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - 18),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (selected != null) setState(() => dateOfBirth = selected);
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => isSaving = true);
    try {
      await ProfileRepository(client).updateProfile(
        fullName: nameController.text.trim(),
        bloodType: bloodType,
        phone: phoneController.text.trim(),
        state: selectedState,
        dateOfBirth: dateOfBirth,
        notificationsEnabled: notificationsEnabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
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
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Edit profile'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
              ],
              validator: ProfileValidation.fullName,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: bloodType,
              decoration: const InputDecoration(labelText: 'Blood type'),
              items: bloodTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => bloodType = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedState,
              decoration: const InputDecoration(labelText: 'State'),
              items: malaysiaStates
                  .map((state) => DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedState = value),
              validator: (value) =>
                  value == null ? 'State is required.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (value) =>
                  ProfileValidation.phone(value, required: false),
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              leading: const Icon(Icons.cake_outlined),
              title: Text(dateLabel(dateOfBirth)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: chooseDate,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: notificationsEnabled,
              onChanged: (value) =>
                  setState(() => notificationsEnabled = value),
              title: const Text('Emergency and event notifications'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSaving ? null : save,
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
