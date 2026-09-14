import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/role_request_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';
import '../../models/user_role.dart';

class RoleApplicationScreen extends StatefulWidget {
  const RoleApplicationScreen({super.key});

  @override
  State<RoleApplicationScreen> createState() => _RoleApplicationScreenState();
}

class _RoleApplicationScreenState extends State<RoleApplicationScreen> {
  final formKey = GlobalKey<FormState>();
  final organisationController = TextEditingController();
  final positionController = TextEditingController();
  final reasonController = TextEditingController();
  UserRole requestedRole = UserRole.admin;
  List<_SelectedDocument> proofDocuments = [];
  bool isSubmitting = false;
  Timer? draftTimer;

  @override
  void initState() {
    super.initState();
    organisationController.addListener(saveDraftSoon);
    positionController.addListener(saveDraftSoon);
    reasonController.addListener(saveDraftSoon);
    restoreDraft();
  }

  @override
  void dispose() {
    organisationController.dispose();
    positionController.dispose();
    reasonController.dispose();
    draftTimer?.cancel();
    super.dispose();
  }

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(
      userId,
      'role_application_draft',
    );
    if (!mounted || draft == null) return;
    organisationController.text = draft['organisation_name'] as String? ?? '';
    positionController.text = draft['staff_position'] as String? ?? '';
    reasonController.text = draft['reason'] as String? ?? '';
    setState(() {
      requestedRole = UserRole.fromDatabase(
        draft['requested_role'] as String?,
      );
      if (requestedRole != UserRole.admin &&
          requestedRole != UserRole.hospital) {
        requestedRole = UserRole.admin;
      }
    });
  }

  void saveDraftSoon() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 400), saveDraft);
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance.saveMap(
      userId,
      'role_application_draft',
      {
        'requested_role': requestedRole.databaseValue,
        'organisation_name': organisationController.text,
        'staff_position': positionController.text,
        'reason': reasonController.text,
      },
    );
  }

  String? requiredValue(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field.' : null;
  }

  Future<void> pickDocuments() async {
    final remainingSlots = 5 - proofDocuments.length;
    if (remainingSlots == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already selected the maximum of 5 documents.'),
        ),
      );
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'doc',
        'docx',
      ],
    );
    if (result.isEmpty || !mounted) return;

    final selected = <_SelectedDocument>[];
    for (final file in result.take(remainingSlots)) {
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Each document must be 5 MB or smaller.'),
          ),
        );
        return;
      }
      final duplicate = proofDocuments.any(
        (document) => document.name == file.name && document.size == size,
      );
      if (!duplicate) {
        selected.add(
          _SelectedDocument(name: file.name, bytes: await file.readAsBytes()),
        );
      }
    }
    if (!mounted) return;

    setState(() {
      proofDocuments = [...proofDocuments, ...selected];
    });
    if (result.length > remainingSlots && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $remainingSlots more document${remainingSlots == 1 ? '' : 's'} could be added.',
          ),
        ),
      );
    } else if (selected.length < result.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duplicate documents were not added.')),
      );
    }
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (proofDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one supporting document.'),
        ),
      );
      return;
    }
    final client = SupabaseService.client;
    if (client == null) return;

    setState(() => isSubmitting = true);
    try {
      await RoleRequestRepository(client).submit(
        requestedRole: requestedRole,
        organisationName: organisationController.text.trim(),
        staffPosition: positionController.text.trim(),
        reason: reasonController.text.trim(),
        documents: proofDocuments
            .map(
              (file) =>
                  RoleRequestDocument(fileName: file.name, bytes: file.bytes),
            )
            .toList(),
      );
      draftTimer?.cancel();
      await LocalCacheService.instance.remove(
        client.auth.currentUser!.id,
        'role_application_draft',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted for review.')),
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on StorageException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid file.')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Apply for staff access'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<UserRole>(
              initialValue: requestedRole,
              decoration: const InputDecoration(labelText: 'Requested role'),
              items: const [UserRole.admin, UserRole.hospital]
                  .map(
                    (role) =>
                        DropdownMenuItem(value: role, child: Text(role.label)),
                  )
                  .toList(),
              onChanged: (role) {
                setState(() => requestedRole = role!);
                saveDraftSoon();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: organisationController,
              validator: requiredValue,
              decoration: const InputDecoration(
                labelText: 'Organisation or hospital name',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: positionController,
              validator: requiredValue,
              decoration: const InputDecoration(labelText: 'Staff position'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              validator: requiredValue,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason for requesting access',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : pickDocuments,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Select supporting documents'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Upload 1–5 PDF, JPG, PNG, WebP, DOC, or DOCX files. Maximum 5 MB each.',
              ),
            ),
            if (proofDocuments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...proofDocuments.asMap().entries.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      entry.value.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _fileSizeLabel(entry.value.bytes.lengthInBytes),
                    ),
                    trailing: IconButton(
                      onPressed: isSubmitting
                          ? null
                          : () => setState(() {
                              proofDocuments = [...proofDocuments]
                                ..removeAt(entry.key);
                            }),
                      tooltip: 'Remove document',
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isSubmitting ? null : submit,
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Submit application'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDocument {
  const _SelectedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get size => bytes.lengthInBytes;
}

String _fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
