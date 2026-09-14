import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../models/donation_event.dart';
import '../local/local_cache_service.dart';

class AdminEventRepository {
  const AdminEventRepository(this.client);

  final SupabaseClient client;

  Future<List<DonationEvent>> getOwnEvents() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    try {
      final rows = await client
          .from('donation_events')
          .select()
          .eq('created_by', user.id)
          .order('starts_at', ascending: false);
      await LocalCacheService.instance.saveList(
        user.id,
        'organisation_events',
        rows.cast<Map<String, Object?>>(),
      );
      return rows.map(DonationEvent.fromMap).toList();
    } on Exception {
      final cached = await LocalCacheService.instance.loadList(
        user.id,
        'organisation_events',
      );
      if (cached == null) rethrow;
      return cached.map(DonationEvent.fromMap).toList();
    }
  }

  Future<void> create({
    required String title,
    required String venue,
    required DateTime startsAt,
    required DateTime endsAt,
    required String description,
    required double? latitude,
    required double? longitude,
    required String? imagePath,
    required DateTime publishAt,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.from('donation_events').insert({
      'title': title,
      'venue': venue,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'description': description.isEmpty ? null : description,
      'status': 'upcoming',
      'created_by': user.id,
      'latitude': latitude,
      'longitude': longitude,
      'image_path': imagePath,
      'publish_at': publishAt.toUtc().toIso8601String(),
    });
  }

  Future<void> update({
    required String id,
    required String title,
    required String venue,
    required DateTime startsAt,
    required DateTime endsAt,
    required String description,
    required double? latitude,
    required double? longitude,
    required String? imagePath,
    required DateTime publishAt,
  }) async {
    await client
        .from('donation_events')
        .update({
          'title': title,
          'venue': venue,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'description': description.isEmpty ? null : description,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'image_path': imagePath,
          'publish_at': publishAt.toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<String> uploadImage({
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('event-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: switch (extension.toLowerCase()) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'image/jpeg',
            },
          ),
        );
    return path;
  }

  Future<void> cancel(String id) async {
    await client
        .from('donation_events')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }
}
