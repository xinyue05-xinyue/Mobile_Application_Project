import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_feedback.dart';
import '../local/local_cache_service.dart';

class FeedbackRepository {
  const FeedbackRepository(this.client);
  final SupabaseClient client;

  static const selection =
      'id, user_id, category, message, status, admin_response, created_at, '
      'attachment_paths, attachment_names, '
      'user:profiles!feedback_user_id_fkey(full_name, role)';
  static const attachmentBucket = 'feedback-attachments';

  Future<void> create({
    required String category,
    required String message,
    List<FeedbackAttachment> attachments = const [],
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    if (attachments.length > 5) {
      throw ArgumentError('Select no more than 5 attachments.');
    }
    final uploadedPaths = <String>[];
    try {
      final uploadId = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < attachments.length; index++) {
        final attachment = attachments[index];
        if (attachment.bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw const FormatException(
            'Each attachment must be 5 MB or smaller.',
          );
        }
        final extension = _extension(attachment.fileName);
        final path = '${user.id}/${uploadId}_$index.$extension';
        await client.storage
            .from(attachmentBucket)
            .uploadBinary(
              path,
              attachment.bytes,
              fileOptions: FileOptions(contentType: _contentType(extension)),
            );
        uploadedPaths.add(path);
      }
      await client.from('feedback').insert({
        'user_id': user.id,
        'category': category,
        'message': message.trim(),
        'attachment_paths': uploadedPaths,
        'attachment_names': attachments.map((item) => item.fileName).toList(),
      });
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        await client.storage.from(attachmentBucket).remove(uploadedPaths);
      }
      rethrow;
    }
  }

  Future<List<UserFeedback>> getMine() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    final rows = await client
        .from('feedback')
        .select(selection)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(UserFeedback.fromMap).toList();
  }

  Future<List<UserFeedback>> getAll() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await client
          .from('feedback')
          .select(selection)
          .order('created_at', ascending: false);
      await LocalCacheService.instance.saveList(
        user.id,
        'feedback_inbox',
        rows.cast<Map<String, Object?>>(),
      );
      return rows.map(UserFeedback.fromMap).toList();
    } on Exception {
      final cached = await LocalCacheService.instance.loadList(
        user.id,
        'feedback_inbox',
      );
      if (cached == null) rethrow;
      return cached.map(UserFeedback.fromMap).toList();
    }
  }

  Future<void> review({
    required String id,
    required String status,
    required String response,
  }) async {
    await client.rpc(
      'review_feedback',
      params: {
        'p_feedback_id': id,
        'p_status': status,
        'p_response': response.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getReplies(String id) async => await client
      .from('feedback_replies')
      .select('id, message, created_at, legacy')
      .eq('feedback_id', id)
      .order('created_at')
      .order('id');

  Future<String> createAttachmentUrl(String path) => client.storage
      .from(attachmentBucket)
      .createSignedUrl(path, const Duration(minutes: 10).inSeconds);

  String _extension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (const {
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'doc',
      'docx',
    }.contains(extension)) {
      return extension;
    }
    throw ArgumentError(
      'Attachments must be PDF, JPG, PNG, WebP, DOC, or DOCX files.',
    );
  }

  String _contentType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}

class FeedbackAttachment {
  const FeedbackAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
