import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'platform_support.dart';

class LocalCacheService {
  LocalCacheService._();

  static final LocalCacheService instance = LocalCacheService._();

  Future<void> saveList(
    String userId,
    String name,
    List<Map<String, Object?>> value,
  ) async {
    if (supportsMobileSqlite) {
      await _saveToSqlite(userId, name, 'list', value);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(userId, name), jsonEncode(value));
  }

  Future<List<Map<String, Object?>>?> loadList(
    String userId,
    String name,
  ) async {
    final value = await _loadValue(userId, name);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  Future<void> saveMap(
    String userId,
    String name,
    Map<String, Object?> value,
  ) async {
    if (supportsMobileSqlite) {
      await _saveToSqlite(userId, name, 'map', value);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(userId, name), jsonEncode(value));
  }

  Future<Map<String, Object?>?> loadMap(String userId, String name) async {
    final value = await _loadValue(userId, name);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  }

  Future<void> remove(String userId, String name) async {
    if (supportsMobileSqlite) {
      final database = await AppDatabase.instance.database;
      await database.delete(
        _tableFor(name),
        where: 'user_id = ? AND cache_key = ?',
        whereArgs: [userId, name],
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId, name));
  }

  String _key(String userId, String name) => 'local_${userId}_$name';

  Future<void> _saveToSqlite(
    String userId,
    String name,
    String valueType,
    Object value,
  ) async {
    final database = await AppDatabase.instance.database;
    await database.insert(_tableFor(name), {
      'user_id': userId,
      'cache_key': name,
      'value_type': valueType,
      'payload': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> _loadFromSqlite(String userId, String name) async {
    final database = await AppDatabase.instance.database;
    final rows = await database.query(
      _tableFor(name),
      columns: ['payload'],
      where: 'user_id = ? AND cache_key = ?',
      whereArgs: [userId, name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['payload'] as String?;
  }

  Future<String?> _loadValue(String userId, String name) async {
    final preferences = await SharedPreferences.getInstance();
    if (!supportsMobileSqlite) {
      return preferences.getString(_key(userId, name));
    }

    final sqliteValue = await _loadFromSqlite(userId, name);
    if (sqliteValue != null) return sqliteValue;

    final legacyValue = preferences.getString(_key(userId, name));
    if (legacyValue == null) return null;
    final decoded = jsonDecode(legacyValue);
    if (decoded is List || decoded is Map) {
      await _saveToSqlite(
        userId,
        name,
        decoded is List ? 'list' : 'map',
        decoded,
      );
      await preferences.remove(_key(userId, name));
    }
    return legacyValue;
  }

  String _tableFor(String name) {
    if (name == 'donor_profile' ||
        name == 'institution_profile' ||
        name.startsWith('role_application_')) {
      return 'user_access_local';
    }
    if (name.startsWith('emergency_') ||
        name.startsWith('hospital_emergency_')) {
      return 'emergency_request_local';
    }
    if (name == 'donation_history' ||
        name.startsWith('event_registration') ||
        name.startsWith('organisation_registration_')) {
      return 'attendance_verification_local';
    }
    if (name.startsWith('reward_')) return 'reward_recognition_local';
    if (name.startsWith('feedback_') || name == 'notifications') {
      return 'feedback_communication_local';
    }
    if (name == 'staff_applications' ||
        name.startsWith('about_us_') ||
        name.startsWith('admin_') ||
        name.startsWith('organisation_donor_analysis')) {
      return 'system_administration_local';
    }
    if (name.startsWith('event_') ||
        name.startsWith('organisation_event') ||
        name.startsWith('centre_') ||
        name.startsWith('venue_')) {
      return 'donation_event_local';
    }

    return 'user_access_local';
  }
}
