import 'package:flutter/material.dart';

import '../data/remote/auth_repository.dart';
import '../data/remote/auth_error_message.dart';
import '../data/remote/supabase_service.dart';
import '../widgets/my_darah_brand.dart';
import 'registration_screen.dart';
import 'role_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (isLoading) return;
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    final client = SupabaseService.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login is unavailable. Configure SUPABASE_URL and '
            'SUPABASE_PUBLISHABLE_KEY, then rebuild the app.',
          ),
        ),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final role = await AuthRepository(client).signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) return;
      final destination = homeForRole(role);
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> forgotPassword() async {
    final initialEmail = emailController.text.trim();
    var enteredEmail = initialEmail;
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your account email. We will send you a secure reset link.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: initialEmail,
              onChanged: (value) => enteredEmail = value,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredEmail.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => isLoading = true);
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseService.passwordResetRedirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, a reset link has been sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const MyDarahMark(size: 92),
            const SizedBox(height: 20),
            const Text(
              'Welcome Back',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: hidePassword,
              onSubmitted: (_) => login(),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: isLoading ? null : login,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegistrationScreen()),
              ),
              child: const Text('Create a donor account'),
            ),
            if (!SupabaseService.isConfigured) ...[
              const SizedBox(height: 16),
              const Text(
                'Login unavailable: Supabase is not configured.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
