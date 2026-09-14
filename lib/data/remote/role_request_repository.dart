import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/role_request.dart';
import '../../models/user_role.dart';
import '../local/local_cache_service.dart';

class RoleRequestRepository {
  const RoleRequestRepository(this.client);

  final SupabaseClient client;

  static const proofBucket = 'role-request-proofs';

  Future<void> submit({
    required UserRole requestedRole,
    required String organisationName,
    required String staffPosition,
    required String reason,
    required List<RoleRequestDocument> documents,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    if (requestedRole != UserRole.admin && requestedRole != UserRole.hospital) {
      throw ArgumentError('Only admin or hospital access can be requested.');
    }

    if (documents.isEmpty || documents.length > 5) {
      throw ArgumentError('Select between 1 and 5 supporting documents.');
    }

    final uploadedPaths = <String>[];
    try {
      final uploadId = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < documents.length; index++) {
        final document = documents[index];
        if (document.bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw const FormatException(
            'Each supporting document must be 5 MB or smaller.',
          );
        }
        final extension = _documentExtension(document.fileName);
        final path = '${user.id}/${uploadId}_$index.$extension';
        await client.storage
            .from(proofBucket)
            .uploadBinary(
              path,
              document.bytes,
              fileOptions: FileOptions(contentType: _contentType(extension)),
            );
        uploadedPaths.add(path);
      }

      await client.from('role_requests').insert({
        'user_id': user.id,
        'requested_role': requestedRole.databaseValue,
        'organisation_name': organisationName,
        'staff_position': staffPosition,
        'reason': reason,
        'proof_path': uploadedPaths.first,
        'proof_paths': uploadedPaths,
        'proof_names': documents.map((document) => document.fileName).toList(),
      });
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        await client.storage.from(proofBucket).remove(uploadedPaths);
      }
      rethrow;
    }
  }

  String _documentExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
      'doc',
      'docx',
    }.contains(extension)) {
      return extension;
    }
    throw ArgumentError(
      'Documents must be PDF, JPG, PNG, WebP, DOC, or DOCX files.',
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

  Future<String> createProofUrl(String proofPath) {
    return client.storage
        .from(proofBucket)
        .createSignedUrl(proofPath, const Duration(minutes: 10).inSeconds);
  }

  Future<List<RoleRequest>> getMine() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    final rows = await client
        .from('role_requests')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(RoleRequest.fromMap).toList();
  }

  Future<List<RoleRequest>> getPending() async {
    final rows = await client
        .from('role_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(RoleRequest.fromMap).toList();
  }

  Future<List<RoleRequest>> getAll() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await client
          .from('role_requests')
          .select()
          .order('created_at', ascending: false);
      await LocalCacheService.instance.saveList(
        user.id,
        'staff_applications',
        rows.cast<Map<String, Object?>>(),
      );
      return rows.map(RoleRequest.fromMap).toList();
    } on Exception {
      final cached = await LocalCacheService.instance.loadList(
        user.id,
        'staff_applications',
      );
      if (cached == null) rethrow;
      return cached.map(RoleRequest.fromMap).toList();
    }
  }

  Future<void> review({
    required String requestId,
    required bool approve,
    String? rejectionReason,
  }) async {
    await client.rpc(
      'review_role_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_review_reason': rejectionReason,
      },
    );
  }
}

class RoleRequestDocument {
  const RoleRequestDocument({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
