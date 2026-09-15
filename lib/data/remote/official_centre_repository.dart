import 'package:sqflite/sqflite.dart';

import '../../models/donation_centre.dart';
import '../local/app_database.dart';
import '../local/platform_support.dart';
import 'supabase_service.dart';

class OfficialCentreRepository {
  OfficialCentreRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<OfficialCentreResult> loadCentres() async {
    try {
      final remote = await _getRemoteCentres();
      if (supportsMobileSqlite) await _replaceCache(remote);
      return OfficialCentreResult(centres: remote, isFromCache: false);
    } on Exception {
      if (!supportsMobileSqlite) {
        return const OfficialCentreResult(centres: [], isFromCache: false);
      }
      final cached = await _getCachedCentres();
      return OfficialCentreResult(centres: cached, isFromCache: true);
    }
  }

  Future<List<DonationCentre>> _getRemoteCentres() async {
    final client = SupabaseService.client;
    if (client == null) throw StateError('Supabase is not configured.');

    final response = await client.functions.invoke('donation-centres');
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Facility service returned ${response.status}.');
    }
    final payload = response.data;
    if (payload is! Map || payload['centres'] is! List) {
      throw const FormatException('Unexpected facility service response.');
    }
    return (payload['centres'] as List)
        .cast<Map<String, Object?>>()
        .map(DonationCentre.fromOfficialMap)
        .toList();
  }

  Future<List<DonationCentre>> _getCachedCentres() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'official_donation_centres',
      orderBy: 'name',
    );
    return rows.map(DonationCentre.fromMap).toList();
  }


  Future<void> _replaceCache(Iterable<DonationCentre> centres) async {
    final database = await _appDatabase.database;
    final existingAddresses = <String, String>{
      for (final row in await database.query(
        'official_donation_centres',
        columns: ['id', 'address'],
      ))
        row['id']! as String: row['address']! as String,
    };
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.delete('official_donation_centres');
      for (final centre in centres) {
        final cachedAddress = existingAddresses[centre.id];
        await transaction.insert('official_donation_centres', {
          ...centre.toMap(),
          'address': cachedAddress ?? centre.address,
          'synced_at': syncedAt,
        });
      }
    });
  }

  Future<String> getAddress(DonationCentre centre) async {
    final client = SupabaseService.client;
    if (client == null) return centre.address;
    try {
      final response = await client.functions.invoke(
        'donation-centres',
        body: {
          'action': 'reverse',
          'lat': centre.latitude,
          'lon': centre.longitude,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('Address service returned ${response.status}.');
      }
      final payload = response.data;
      if (payload is! Map || payload['address'] is! String) {
        throw const FormatException('Unexpected address service response.');
      }
      final address = payload['address'] as String;
      if (supportsMobileSqlite) {
        final database = await _appDatabase.database;
        await database.update(
          'official_donation_centres',
          {'address': address},
          where: 'id = ?',
          whereArgs: [centre.id],
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return address;
    } on Exception {
      return centre.address;
    }
  }

  Future<LocationSearchResult> searchLocation(String query) async {
    final results = await searchLocations(query);
    if (results.isEmpty) throw StateError('Location not found.');
    return results.first;
  }

  Future<List<LocationSearchResult>> searchLocations(String query) async {
    final client = SupabaseService.client;
    if (client == null) throw StateError('Supabase is not configured.');
    final response = await client.functions.invoke(
      'donation-centres',
      body: {'action': 'search', 'query': query},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Location search returned ${response.status}.');
    }
    final payload = response.data;
    if (payload is! Map || payload['results'] is! List) {
      throw const FormatException('Invalid search results.');
    }
    return (payload['results'] as List)
        .cast<Map<String, Object?>>()
        .map(
          (row) => LocationSearchResult(
            latitude: (row['lat'] as num).toDouble(),
            longitude: (row['lon'] as num).toDouble(),
            address: row['address'] as String,
          ),
        )
        .toList();
  }
}

class LocationSearchResult {
  const LocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
  final double latitude;
  final double longitude;
  final String address;
}

class OfficialCentreResult {
  const OfficialCentreResult({
    required this.centres,
    required this.isFromCache,
  });

  final List<DonationCentre> centres;
  final bool isFromCache;
}
