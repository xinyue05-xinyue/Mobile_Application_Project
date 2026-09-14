import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/reward_item.dart';
import '../../models/reward_redemption.dart';
import '../local/local_cache_service.dart';

// REWARD REPOSITORY: Reads cached catalogues but performs redemptions in Supabase.

class RewardRepository {
  const RewardRepository(this.client);

  final SupabaseClient client;

  Future<List<RewardItem>> getItems() async {
    final user = client.auth.currentUser;
    try {
      final rows = await client
          .from('reward_items')
          .select()
          .eq('is_active', true)
          .order('points_cost');
      if (user != null) {
        await LocalCacheService.instance.saveList(
          user.id,
          'reward_catalogue',
          rows.cast<Map<String, Object?>>(),
        );
      }
      return rows.map(RewardItem.fromMap).toList();
    } on Exception {
      if (user == null) rethrow;
      final cached = await LocalCacheService.instance.loadList(
        user.id,
        'reward_catalogue',
      );
      if (cached == null) rethrow;
      return cached.map(RewardItem.fromMap).toList();
    }
  }

  Future<List<RewardItem>> getAllItems() async {
    final rows = await client
        .from('reward_items')
        .select()
        .order('created_at', ascending: false);
    return rows.map(RewardItem.fromMap).toList();
  }

  Future<void> createItem({
    required String name,
    required String description,
    required String category,
    required int pointsCost,
    required int stockQuantity,
    required String iconKey,
    String? imageUrl,
  }) => client.from('reward_items').insert({
    'name': name,
    'description': description,
    'category': category,
    'points_cost': pointsCost,
    'stock_quantity': stockQuantity,
    'icon_key': iconKey,
    'image_url': imageUrl,
    'is_active': true,
  });

  Future<void> updateItem({
    required String id,
    required String name,
    required String description,
    required String category,
    required int pointsCost,
    required int stockQuantity,
    required String iconKey,
    required bool isActive,
    String? imageUrl,
  }) => client
      .from('reward_items')
      .update({
        'name': name,
        'description': description,
        'category': category,
        'points_cost': pointsCost,
        'stock_quantity': stockQuantity,
        'icon_key': iconKey,
        'image_url': imageUrl,
        'is_active': isActive,
      })
      .eq('id', id);

  Future<void> archiveItem(String id) =>
      client.from('reward_items').update({'is_active': false}).eq('id', id);

  Future<String> uploadImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '${client.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('reward-images')
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
    return client.storage.from('reward-images').getPublicUrl(path);
  }

  Future<List<RewardRedemption>> getMine() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    final rows = await client
        .from('reward_redemptions')
        .select(
          'id, points_spent, redemption_code, status, created_at, '
          'reward_item:reward_items(name)',
        )
        .eq('donor_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(RewardRedemption.fromMap).toList();
  }

  Future<int> getBalance() async {
    final user = client.auth.currentUser;
    if (user == null) return 0;
    final rows = await client
        .from('reward_transactions')
        .select('points')
        .eq('donor_id', user.id);
    return rows.fold<int>(
      0,
      (total, row) => total + (row['points'] as num).toInt(),
    );
  }

  Future<({String code, int remainingPoints})> redeem(String itemId) async {
    final rows = await client.rpc(
      'redeem_reward',
      params: {'p_reward_item_id': itemId},
    );
    final row = (rows as List).first as Map<String, Object?>;
    return (
      code: row['redemption_code']! as String,
      remainingPoints: (row['remaining_points']! as num).toInt(),
    );
  }
}
