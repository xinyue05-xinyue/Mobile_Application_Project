import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gsjcocwsvlbuizxpuzqo.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_CPDXVJJntMLVA5NBoGyJ5A_VUsq485k',
  );
  static bool _initialized = false;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String get passwordResetRedirectUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/';
    }
    return 'io.supabase.mydarah://reset-password';
  }

  static SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _initialized = true;
  }
}
