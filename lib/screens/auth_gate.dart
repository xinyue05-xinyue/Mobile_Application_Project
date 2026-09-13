import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/navigation/app_navigator.dart';
import '../data/remote/auth_repository.dart';
import '../data/remote/password_recovery_service.dart';
import '../data/remote/supabase_service.dart';
import '../models/user_role.dart';
import '../widgets/my_darah_brand.dart';
import 'role_home.dart';
import 'reset_password_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<UserRole?>? roleFuture;
  StreamSubscription<AuthState>? authSubscription;
  bool passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    passwordRecovery = PasswordRecoveryService.instance.active.value;
    PasswordRecoveryService.instance.active.addListener(
      _passwordRecoveryChanged,
    );
    final client = SupabaseService.client;
    authSubscription = client?.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          PasswordRecoveryService.instance.markActive();
        }
      },
      onError: (_, _) {},
    );
    if (client != null && client.auth.currentSession != null) {
      roleFuture = AuthRepository(client).getCurrentRole();
    }
  }

  @override
  void dispose() {
    PasswordRecoveryService.instance.active.removeListener(
      _passwordRecoveryChanged,
    );
    authSubscription?.cancel();
    super.dispose();
  }

  void _passwordRecoveryChanged() {
    if (!mounted) return;
    final recoveryActive = PasswordRecoveryService.instance.active.value;
    setState(() {
      passwordRecovery = recoveryActive;
    });

    if (recoveryActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> retry() async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentSession == null) {
      setState(() {
        roleFuture = null;
      });
      return;
    }
    setState(() {
      roleFuture = AuthRepository(client).getCurrentRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (passwordRecovery) {
      return ResetPasswordScreen(
        onComplete: () {
          PasswordRecoveryService.instance.complete();
          setState(() => roleFuture = null);
        },
      );
    }
    final future = roleFuture;
    if (future == null) return const WelcomeScreen();

    return FutureBuilder<UserRole?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupScreen();
        }
        if (snapshot.hasError) {
          return _SessionErrorScreen(onRetry: retry);
        }
        final role = snapshot.data;
        return role == null ? const WelcomeScreen() : homeForRole(role);
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyDarahMark(size: 76),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Restoring your session...'),
          ],
        ),
      ),
    );
  }
}

class _SessionErrorScreen extends StatelessWidget {
  const _SessionErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Unable to restore your account.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              TextButton(
                onPressed: () async {
                  await SupabaseService.client?.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (_) => false,
                    );
                  }
                },
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
