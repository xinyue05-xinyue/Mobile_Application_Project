import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'feedback_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme/app_theme.dart';
import '../data/remote/feedback_repository.dart';
import '../data/remote/supabase_service.dart';
import '../data/local/local_cache_service.dart';
import '../models/user_feedback.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.useDonorColors = false,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
  });

  final bool useDonorColors;
  final bool useOrganisationColors;
  final bool useHospitalColors;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final message = TextEditingController();
  String category = 'general';
  bool submitting = false;
  List<FeedbackAttachment> attachments = [];
  late Future<List<UserFeedback>> feedback;
  Timer? refreshTimer;
  Timer? draftTimer;

  @override
  void initState() {
    super.initState();
    message.addListener(saveDraftSoon);
    restoreDraft();
    feedback = load();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !submitting) {
        setState(() {
          feedback = load();
        });
      }
    });
  }

  @override
  void dispose() {
    message.dispose();
    refreshTimer?.cancel();
    draftTimer?.cancel();
    super.dispose();
  }

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(
      userId,
      'feedback_draft',
    );
    if (!mounted || draft == null) return;
    message.text = draft['message'] as String? ?? '';
    setState(() => category = draft['category'] as String? ?? 'general');
  }

  void saveDraftSoon() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 400), saveDraft);
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    if (message.text.trim().isEmpty && category == 'general') {
      await LocalCacheService.instance.remove(userId, 'feedback_draft');
      return;
    }
    await LocalCacheService.instance.saveMap(userId, 'feedback_draft', {
      'category': category,
      'message': message.text,
    });
  }

  Future<List<UserFeedback>> load() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return FeedbackRepository(client).getMine();
  }

  Future<void> submit() async {
    final text = message.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 10 characters.')),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      await FeedbackRepository(
        SupabaseService.client!,
      ).create(category: category, message: text, attachments: attachments);
      message.clear();
      draftTimer?.cancel();
      await LocalCacheService.instance.remove(
        SupabaseService.client!.auth.currentUser!.id,
        'feedback_draft',
      );
      if (!mounted) return;
      setState(() {
        category = 'general';
        attachments = [];
        feedback = load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback sent to the system admin.')),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? 'Invalid file.')),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> pickAttachments() async {
    final remaining = 5 - attachments.length;
    if (remaining == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already selected 5 attachments.')),
      );
      return;
    }
    final files = await FilePicker.pickFiles(
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
    if (files.isEmpty || !mounted) return;
    final added = <FeedbackAttachment>[];
    for (final file in files.take(remaining)) {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Each attachment must be 5 MB or smaller.'),
          ),
        );
        return;
      }
      final duplicate = attachments.any(
        (item) =>
            item.fileName == file.name && item.bytes.length == bytes.length,
      );
      if (!duplicate) {
        added.add(FeedbackAttachment(fileName: file.name, bytes: bytes));
      }
    }
    if (!mounted) return;
    setState(() => attachments = [...attachments, ...added]);
  }

  String dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.useDonorColors
          ? AppTheme.donorBackground
          : widget.useOrganisationColors
          ? AppTheme.organisationBackground
          : widget.useHospitalColors
          ? AppTheme.hospitalBackground
          : null,
      appBar: AppBar(
        backgroundColor: widget.useDonorColors
            ? AppTheme.donorHeader
            : widget.useOrganisationColors
            ? AppTheme.organisationHeader
            : widget.useHospitalColors
            ? AppTheme.hospitalHeader
            : null,
        foregroundColor:
            widget.useDonorColors ||
                widget.useOrganisationColors ||
                widget.useHospitalColors
            ? Colors.white
            : null,
        titleTextStyle: widget.useDonorColors
            ? AppTheme.donorHeaderTitleStyle
            : widget.useOrganisationColors
            ? AppTheme.organisationHeaderTitleStyle
            : widget.useHospitalColors
            ? AppTheme.hospitalHeaderTitleStyle
            : null,
        title: const Text('Feedback'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Send feedback',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General')),
              DropdownMenuItem(value: 'bug', child: Text('Report a problem')),
              DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
              DropdownMenuItem(
                value: 'service',
                child: Text('Service feedback'),
              ),
            ],
            onChanged: (value) {
              setState(() => category = value ?? 'general');
              saveDraftSoon();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText:
                  'Tell the system administrator what happened or what can be improved.',
              alignLabelWithHint: true,
            ),
          ),
          OutlinedButton.icon(
            onPressed: submitting ? null : pickAttachments,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Select supporting documents'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Optional: upload up to 5 PDF, JPG, PNG, WebP, DOC, or DOCX files. Maximum 5 MB each.',
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...attachments.asMap().entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    entry.value.fileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_fileSize(entry.value.bytes.lengthInBytes)),
                  trailing: IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: submitting
                        ? null
                        : () => setState(() {
                            attachments = [...attachments]..removeAt(entry.key);
                          }),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: submitting ? null : submit,
            style: widget.useOrganisationColors
                ? FilledButton.styleFrom(
                    backgroundColor: AppTheme.organisation,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.organisationPalette[1],
                    disabledForegroundColor: AppTheme.organisationHeader,
                  )
                : widget.useHospitalColors
                ? FilledButton.styleFrom(
                    backgroundColor: AppTheme.hospital,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.hospitalPalette[1],
                    disabledForegroundColor: AppTheme.hospitalHeader,
                  )
                : null,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Submit feedback'),
          ),
          const SizedBox(height: 28),
          Text('My feedback', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<UserFeedback>>(
            future: feedback,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load feedback. Please check your connection.',
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const Text('No feedback submitted yet.');
              }
              return Column(
                children: items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(
                            item.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeedbackDetailScreen(
                                  item: item,
                                  useDonorColors: widget.useDonorColors,
                                  useOrganisationColors:
                                      widget.useOrganisationColors,
                                  useHospitalColors: widget.useHospitalColors,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() {
                                feedback = load();
                              });
                            }
                          },
                          subtitle: Text(
                            '${item.category} • ${dateLabel(item.createdAt)}\n'
                            'Status: ${item.statusLabel}'
                            '${item.attachmentPaths.isEmpty ? '' : '\n${item.attachmentPaths.length} attachment${item.attachmentPaths.length == 1 ? '' : 's'}'}'
                            '${item.adminResponse == null ? '' : '\nAdmin: ${item.adminResponse}'}',
                          ),
                          isThreeLine: item.adminResponse != null,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _fileSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';
