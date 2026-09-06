import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/organisation_profile.dart';

class OrganisationProfileRepository {
  const OrganisationProfileRepository(this.client);

  /// Changes whenever the signed-in institution profile is saved.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final SupabaseClient client;

  Future<OrganisationProfile?> getForOwner(String ownerId) async {
    final row = await client
        .from('organisation_profiles')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null ? null : OrganisationProfile.fromMap(row);
  }

  Future<OrganisationProfile?> getMine() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    return getForOwner(user.id);
  }

  Future<String> uploadImage(Uint8List bytes, String extension) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('organisation-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'png'
                ? 'image/png'
                : extension == 'webp'
                ? 'image/webp'
                : 'image/jpeg',
          ),
        );
    return path;
  }

  Future<void> save({
    required String displayName,
    required String contactPhone,
    required String address,
    required String description,
    required String? imagePath,
    required double? latitude,
    required double? longitude,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    await client.from('organisation_profiles').upsert({
      'owner_id': user.id,
      'display_name': displayName,
      'contact_phone': contactPhone.isEmpty ? null : contactPhone,
      'address': address.isEmpty ? null : address,
      'description': description.isEmpty ? null : description,
      'image_path': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'owner_id');
    revision.value++;
  }
}
