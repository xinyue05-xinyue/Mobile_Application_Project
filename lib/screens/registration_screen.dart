import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/remote/auth_repository.dart';
import '../data/remote/auth_error_message.dart';
import '../data/remote/supabase_service.dart';
import '../widgets/my_darah_brand.dart';
import '../utils/profile_validation.dart';
import 'donor/donor_shell.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool hidePassword = true;
  bool isLoading = false;
  DateTime? dateOfBirth;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (isLoading) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    final client = SupabaseService.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase is not configured.')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final signedIn = await AuthRepository(client).signUp(
        fullName: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        phone: phoneController.text.trim(),
        dateOfBirth: dateOfBirth!,
      );
      if (!mounted) return;
      if (signedIn) {
        await Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DonorShell()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Check your email, then log in.'),
          ),
        );
        await Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String? requiredValue(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  String dateLabel() {
    final value = dateOfBirth;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create donor account')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const MyDarahMark(size: 76),
            const SizedBox(height: 24),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
              ],
              validator: ProfileValidation.fullName,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: ProfileValidation.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '0123456789',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FormField<DateTime>(
              validator: (_) =>
                  dateOfBirth == null ? 'Date of birth is required.' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: field.hasError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(dateLabel()),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      await chooseDate();
                      field.didChange(dateOfBirth);
                    },
                  ),
                  if (field.errorText case final error?)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final requiredError = requiredValue(value, 'Email');
                if (requiredError != null) return requiredError;
                if (!value!.contains('@')) return 'Enter a valid email.';
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: hidePassword,
              validator: (value) {
                if ((value ?? '').length < 8) {
                  return 'Use at least 8 characters.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                  icon: Icon(
                    hidePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: hidePassword,
              validator: (value) => value != passwordController.text
                  ? 'Passwords do not match.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : register,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
