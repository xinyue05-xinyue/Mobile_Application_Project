import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/event_schedule.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/feedback_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';
import '../../models/user_feedback.dart';

class FeedbackInboxScreen extends StatefulWidget {
  const FeedbackInboxScreen({super.key});

  @override
  State<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends State<FeedbackInboxScreen> {
  late Future<List<UserFeedback>> feedback;
  Timer? timer;
  bool reviewing = false;

  @override
  void initState() {
    super.initState();
    feedback = load();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !reviewing) {
        setState(() {
          feedback = load();
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<List<UserFeedback>> load() =>
      FeedbackRepository(SupabaseService.client!).getAll();

  Future<void> review(UserFeedback item) async {
    if (reviewing) return;
    reviewing = true;
    List<Map<String, dynamic>> replies;
    try {
      replies = await FeedbackRepository(
        SupabaseService.client!,
      ).getReplies(item.id);
    } catch (_) {
      reviewing = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load reply history. Check your connection and apply SQL migration 021.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      reviewing = false;
      return;
    }
    var status = item.status;
    final response = TextEditingController();
    final userId = SupabaseService.client!.auth.currentUser!.id;
    final draftName = 'feedback_reply_draft_${item.id}';
    final draft = await LocalCacheService.instance.loadMap(userId, draftName);
    if (draft != null) {
      response.text = draft['response'] as String? ?? '';
      status = draft['status'] as String? ?? status;
    }
    if (!mounted) {
      response.dispose();
      reviewing = false;
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.systemAdminBackground,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(item.userName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.userRole} • ${item.category}'),
                const SizedBox(height: 12),
                Text(item.message),
                if (replies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Previous replies'),
                  for (final reply in replies)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${reply['message']}'),
                      subtitle: Text(
                        eventDateTime(
                          DateTime.parse(reply['created_at'] as String),
                        ),
                      ),
                    ),
                ],
                if (item.attachmentPaths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Attachments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...List.generate(item.attachmentPaths.length, (index) {
                    final name = index < item.attachmentNames.length
                        ? item.attachmentNames[index]
                        : 'Attachment ${index + 1}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openAttachment(item.attachmentPaths[index]),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Submitted')),
                    DropdownMenuItem(
                      value: 'reviewed',
                      child: Text('Reviewed'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: response,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Add a new reply (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.systemAdmin,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.systemAdmin,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await FeedbackRepository(
          SupabaseService.client!,
        ).review(id: item.id, status: status, response: response.text);
        await LocalCacheService.instance.remove(userId, draftName);
        if (mounted) {
          setState(() {
            feedback = load();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback response saved.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to save response. Please try again.'),
            ),
          );
        }
      }
    } else {
      await LocalCacheService.instance.saveMap(userId, draftName, {
        'status': status,
        'response': response.text,
      });
    }
    response.dispose();
    reviewing = false;
  }

  Future<void> openAttachment(String path) async {
    try {
      final url = await FeedbackRepository(
        SupabaseService.client!,
      ).createAttachmentUrl(path);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Unable to open attachment.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open attachment: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.systemAdminBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.systemAdminHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
        title: const Text('Feedback inbox'),
      ),
      body: FutureBuilder<List<UserFeedback>>(
        future: feedback,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load feedback: ${snapshot.error}'),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No feedback yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  onTap: () => review(item),
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(item.userName),
                  subtitle: Text(
                    '${item.userRole} • ${item.category}\n${item.message}',
                  ),
                  isThreeLine: true,
                  trailing: Text(item.statusLabel),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
