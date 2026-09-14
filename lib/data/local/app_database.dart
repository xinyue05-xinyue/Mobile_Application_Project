import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

// LOCAL DATABASE: Creates and upgrades the SQLite cache used on mobile devices.

class AppDatabase {
  AppDatabase._();

  // Singleton connection prevents the app from opening the database repeatedly.
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  // Opens my_darah.db on first use and reuses it afterward.
  Future<Database> get database async {
    if (_database case final database?) return database;

    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'my_darah.db'),
      version: 9,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _database!;
  }

  // Creates every table required by a new installation.
  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE donation_centres (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        state TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        operating_hours TEXT,
        source_id TEXT,
        synced_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE donation_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        venue TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        ends_at TEXT NOT NULL,
        status TEXT NOT NULL,
        description TEXT,
        latitude REAL,
        longitude REAL,
        image_path TEXT,
        created_by TEXT,
        organiser_name TEXT,
        publish_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE emergency_requests (
        id TEXT PRIMARY KEY,
        hospital_id TEXT NOT NULL,
        blood_type TEXT NOT NULL,
        urgency TEXT NOT NULL,
        deadline TEXT NOT NULL,
        status TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE reward_transactions (
        id TEXT PRIMARY KEY,
        donor_id TEXT NOT NULL,
        points INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        donation_id TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _createGovernmentStats(database);
    await _createOfficialCentres(database);
    await _createModuleCaches(database);
  }

  // Migrates existing installations while preserving their cached data.
  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createGovernmentStats(database);
    if (oldVersion < 3) {
      await database.execute('DROP TABLE IF EXISTS government_donation_stats');
      await _createGovernmentStats(database);
    }
    if (oldVersion < 4) await _createOfficialCentres(database);
    if (oldVersion < 6) {
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN created_by TEXT',
      );
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN organiser_name TEXT',
      );
    }
    if (oldVersion < 7) {
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN publish_at TEXT',
      );
    }
    if (oldVersion < 8) {
      await database.execute('''
        CREATE TABLE emergency_requests_new (
          id TEXT PRIMARY KEY,
          hospital_id TEXT NOT NULL,
          blood_type TEXT NOT NULL,
          urgency TEXT NOT NULL,
          deadline TEXT NOT NULL,
          status TEXT NOT NULL,
          synced_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        INSERT INTO emergency_requests_new (
          id, hospital_id, blood_type, urgency, deadline, status, synced_at
        )
        SELECT id, hospital_id, blood_type, urgency, deadline, status, synced_at
        FROM emergency_requests
      ''');
      await database.execute('DROP TABLE emergency_requests');
      await database.execute(
        'ALTER TABLE emergency_requests_new RENAME TO emergency_requests',
      );
    }
    if (oldVersion < 5) {
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN latitude REAL',
      );
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN longitude REAL',
      );
      await database.execute(
        'ALTER TABLE donation_events ADD COLUMN image_path TEXT',
      );
    }
    if (oldVersion < 9) await _createModuleCaches(database);
  }

  // Cached public statistics downloaded from the government data source.
  Future<void> _createGovernmentStats(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS government_donation_stats (
        date TEXT NOT NULL,
        state TEXT NOT NULL,
        blood_type TEXT NOT NULL,
        donations INTEGER NOT NULL,
        synced_at TEXT NOT NULL,
        PRIMARY KEY (date, state, blood_type)
      )
    ''');
  }

  // Cached official blood collection centres used by maps and search.
  Future<void> _createOfficialCentres(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS official_donation_centres (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        state TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        operating_hours TEXT,
        source_id TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  // Every business module owns one SQLite table for cached lists and drafts.
  // The JSON payload keeps the storage reusable while Supabase remains the
  // authoritative database for shared and security-sensitive records.
  Future<void> _createModuleCaches(Database database) async {
    const tables = [
      'user_access_local',
      'donation_event_local',
      'emergency_request_local',
      'attendance_verification_local',
      'reward_recognition_local',
      'feedback_communication_local',
      'system_administration_local',
    ];

    for (final table in tables) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS $table (
          user_id TEXT NOT NULL,
          cache_key TEXT NOT NULL,
          value_type TEXT NOT NULL CHECK (value_type IN ('map', 'list')),
          payload TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (user_id, cache_key)
        )
      ''');
    }
  }
}
