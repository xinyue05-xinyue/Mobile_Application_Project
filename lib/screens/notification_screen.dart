import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../data/remote/notification_repository.dart';
import '../data/remote/supabase_service.dart';
import '../models/app_notification.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    this.useDonorColors = false,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
    this.useSystemAdminColors = false,
  });

  final bool useDonorColors;
  final bool useOrganisationColors;
  final bool useHospitalColors;
  final bool useSystemAdminColors;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<AppNotification>> notifications;

  @override
  void initState() {
    super.initState();
    notifications = loadNotifications();
  }

  Future<List<AppNotification>> loadNotifications() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return NotificationRepository(client).getMine();
  }

  Future<void> refresh() async {
    setState(() {
      notifications = loadNotifications();
    });
    await notifications;
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final client = SupabaseService.client;
    if (client == null) return;
    await NotificationRepository(client).markRead(notification.id);
    await refresh();
  }

  Future<void> markAllRead() async {
    final client = SupabaseService.client;
    if (client == null) return;
    await NotificationRepository(client).markAllRead();
    await refresh();
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  IconData iconFor(String type) => switch (type) {
    'emergency' => Icons.emergency_outlined,
    'event' => Icons.event_outlined,
    'role' => Icons.badge_outlined,
    'reward' => Icons.stars_outlined,
    'feedback' => Icons.feedback_outlined,
    _ => Icons.notifications_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.useDonorColors
          ? AppTheme.donorBackground
          : widget.useOrganisationColors
          ? AppTheme.organisationBackground
          : widget.useHospitalColors
          ? AppTheme.hospitalBackground
          : widget.useSystemAdminColors
          ? AppTheme.systemAdminBackground
          : null,
      appBar: AppBar(
        backgroundColor: widget.useDonorColors
            ? AppTheme.donorHeader
            : widget.useOrganisationColors
            ? AppTheme.organisationHeader
            : widget.useHospitalColors
            ? AppTheme.hospitalHeader
            : widget.useSystemAdminColors
            ? AppTheme.systemAdminHeader
            : null,
        foregroundColor:
            widget.useDonorColors ||
                widget.useOrganisationColors ||
                widget.useHospitalColors ||
                widget.useSystemAdminColors
            ? Colors.white
            : null,
        titleTextStyle: widget.useDonorColors
            ? AppTheme.donorHeaderTitleStyle
            : widget.useOrganisationColors
            ? AppTheme.organisationHeaderTitleStyle
            : widget.useHospitalColors
            ? AppTheme.hospitalHeaderTitleStyle
            : widget.useSystemAdminColors
            ? AppTheme.systemAdminHeaderTitleStyle
            : null,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: markAllRead,
            style:
                widget.useDonorColors ||
                    widget.useOrganisationColors ||
                    widget.useHospitalColors ||
                    widget.useSystemAdminColors
                ? TextButton.styleFrom(foregroundColor: Colors.white)
                : null,
            child: const Text('Read all'),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load notifications.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.notifications_none, size: 64),
                  SizedBox(height: 12),
                  Center(child: Text('No notifications yet.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = items[index];
                return Card(
                  color: notification.isRead
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    onTap: () => markRead(notification),
                    leading: Icon(iconFor(notification.type)),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${notification.message}\n${dateLabel(notification.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: notification.isRead
                        ? null
                        : const Icon(Icons.circle, size: 10),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
