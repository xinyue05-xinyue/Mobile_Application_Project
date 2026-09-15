import 'package:sqflite/sqflite.dart';

import '../../models/donation_centre.dart';
import '../../models/donation_event.dart';
import '../local/app_database.dart';


class LocalDataRepository {
  LocalDataRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<void> ensureStarterData() async {
    final database = await _appDatabase.database;
    final centreCount =
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM donation_centres'),
        ) ??
        0;
    final eventCount =
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM donation_events'),
        ) ??
        0;

    if (centreCount == 0) {
      await saveCentres(const [
        DonationCentre(
          id: 'starter-pdn',
          name: 'Pusat Darah Negara',
          address: 'Jalan Tun Razak, Kuala Lumpur',
          state: 'Kuala Lumpur',
          latitude: 3.1718,
          longitude: 101.7066,
          operatingHours: 'Check official operating hours before visiting',
        ),
        DonationCentre(
          id: 'starter-hkl',
          name: 'Hospital Kuala Lumpur',
          address: 'Jalan Pahang, Kuala Lumpur',
          state: 'Kuala Lumpur',
          latitude: 3.1736,
          longitude: 101.7006,
          operatingHours: 'Check official operating hours before visiting',
        ),
      ]);
    }

    if (eventCount == 0) {
      final now = DateTime.now();
      final firstStart = DateTime(now.year, now.month, now.day + 7, 9);
      final secondStart = DateTime(now.year, now.month, now.day + 14, 10);
      await saveEvents([
        DonationEvent(
          id: 'starter-event-1',
          title: 'Community Blood Donation Drive',
          venue: 'Kuala Lumpur',
          startsAt: firstStart,
          endsAt: firstStart.add(const Duration(hours: 6)),
          status: 'upcoming',
          description:
              'Starter offline data. Replace with verified remote data.',
        ),
        DonationEvent(
          id: 'starter-event-2',
          title: 'Hospital Blood Donation Campaign',
          venue: 'Selangor',
          startsAt: secondStart,
          endsAt: secondStart.add(const Duration(hours: 5)),
          status: 'upcoming',
          description:
              'Starter offline data. Replace with verified remote data.',
        ),
      ]);
    }
  }

  Future<List<DonationCentre>> getCentres() async {
    final database = await _appDatabase.database;
    final rows = await database.query('donation_centres', orderBy: 'name');
    return rows.map(DonationCentre.fromMap).toList();
  }

  Future<void> saveCentres(Iterable<DonationCentre> centres) async {
    final database = await _appDatabase.database;
    final batch = database.batch();
    final syncedAt = DateTime.now().toUtc().toIso8601String();

    for (final centre in centres) {
      batch.insert('donation_centres', {
        ...centre.toMap(),
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceCentres(Iterable<DonationCentre> centres) async {
    final database = await _appDatabase.database;
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.delete('donation_centres');
      for (final centre in centres) {
        await transaction.insert('donation_centres', {
          ...centre.toMap(),
          'synced_at': syncedAt,
        });
      }
    });
  }

  Future<List<DonationEvent>> getEvents() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'donation_events',
      where: 'status != ? AND (publish_at IS NULL OR publish_at <= ?)',
      whereArgs: ['cancelled', DateTime.now().toUtc().toIso8601String()],
      orderBy: 'starts_at',
    );
    return rows.map(DonationEvent.fromMap).toList();
  }

  Future<void> saveEvents(Iterable<DonationEvent> events) async {
    final database = await _appDatabase.database;
    final batch = database.batch();
    final syncedAt = DateTime.now().toUtc().toIso8601String();

    for (final event in events) {
      batch.insert('donation_events', {
        ...event.toMap(),
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceEvents(Iterable<DonationEvent> events) async {
    final database = await _appDatabase.database;
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.delete('donation_events');
      for (final event in events) {
        await transaction.insert('donation_events', {
          ...event.toMap(),
          'synced_at': syncedAt,
        });
      }
    });
  }
}
