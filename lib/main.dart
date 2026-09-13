import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'app/navigation/app_navigator.dart';
import 'data/local/event_reminder_service.dart';
import 'data/remote/password_recovery_service.dart';
import 'data/remote/supabase_service.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EventReminderService.instance.initialize();
  await SupabaseService.initialize();
  await PasswordRecoveryService.instance.initialize();
  runApp(const MyDarahApp());
}

class MyDarahApp extends StatelessWidget {
  const MyDarahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'MyDarah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
