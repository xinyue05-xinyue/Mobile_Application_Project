import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_notification.dart';
import '../local/local_cache_service.dart';


class NotificationRepository {
  const NotificationRepository(this.client);

  final SupabaseClient client;

  Future<List<AppNotification>> getMine() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      await LocalCacheService.instance.saveList(
        user.id,
        'notifications',
        rows.cast<Map<String, Object?>>(),
      );
      return rows.map(AppNotification.fromMap).toList();
    } on Exception {
      final cached = await LocalCacheService.instance.loadList(
        user.id,
        'notifications',
      );
      if (cached == null) rethrow;
      return cached.map(AppNotification.fromMap).toList();
    }
  }

  Future<int> getUnreadCount() async {
    final rows = await client
        .from('notifications')
        .select('id')
        .eq('is_read', false);
    return rows.length;
  }

  Future<void> markRead(String id) async {
    await client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
  }
}
