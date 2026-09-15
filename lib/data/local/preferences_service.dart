import 'package:shared_preferences/shared_preferences.dart';


class PreferencesService {
  PreferencesService._();

  static final PreferencesService instance = PreferencesService._();
  static const _notificationsKey = 'notifications_enabled';
  static const _lastSyncKey = 'last_sync_at';

  Future<bool> notificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_notificationsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, enabled);
  }

  Future<DateTime?> lastSyncAt() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<void> setLastSyncAt(DateTime value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastSyncKey, value.toUtc().toIso8601String());
  }
}
