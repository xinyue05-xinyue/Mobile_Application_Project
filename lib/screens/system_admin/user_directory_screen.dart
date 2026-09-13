import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/remote/system_admin_repository.dart';
import 'user_detail_screen.dart';

class UserDirectoryScreen extends StatefulWidget {
  const UserDirectoryScreen({
    super.key,
    required this.title,
    required this.roles,
  });

  final String title;
  final Set<String> roles;

  @override
  State<UserDirectoryScreen> createState() => _UserDirectoryScreenState();
}

class _UserDirectoryScreenState extends State<UserDirectoryScreen> {
  late Future<List<SystemUserSummary>> users;

  @override
  void initState() {
    super.initState();
    users = loadUsers();
  }

  Future<List<SystemUserSummary>> loadUsers() async {
    final client = SupabaseService.client;
    if (client == null) return const [];
    final all = await SystemAdminRepository(client).getUserDirectory();
    return all.where((user) => widget.roles.contains(user.role)).toList();
  }

  Future<void> refresh() async {
    final refreshed = loadUsers();
    setState(() {
      users = refreshed;
    });
    await refreshed;
  }

  bool get canRemoveStaff => widget.roles.any(
    (role) => role == 'admin' || role == 'hospital' || role == 'hospital_admin',
  );

  Future<void> removeAccess(SystemUserSummary user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove staff access?'),
        content: Text(
          '${user.fullName} will become a donor and will no longer be able to '
          'manage ${user.role == 'admin' ? 'events and centres' : 'hospital emergency requests'}. '
          'Their account and existing records will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await SystemAdminRepository(client).demoteStaffToDonor(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} is now a donor.')),
      );
      await refresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String roleLabel(String role) => switch (role) {
    'admin' => 'Organisation admin',
    'hospital' || 'hospital_admin' => 'Hospital',
    'system_admin' => 'System administrator',
    _ => 'Donor',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.systemAdminBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.systemAdminHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<SystemUserSummary>>(
        future: users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Unable to load accounts. Try again'),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'account' : 'accounts'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Card(child: ListTile(title: Text('No accounts found.')))
                else
                  ...items.map(
                    (user) => Card(
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(user: user),
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          child: Text(
                            user.fullName.trim().isEmpty
                                ? '?'
                                : user.fullName.trim()[0].toUpperCase(),
                          ),
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(
                          '${roleLabel(user.role)}'
                          '${user.bloodType == null ? '' : ' • ${user.bloodType}'}\n'
                          'Joined ${dateLabel(user.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: canRemoveStaff
                            ? IconButton(
                                onPressed: () => removeAccess(user),
                                tooltip: 'Remove staff access',
                                icon: const Icon(Icons.person_remove_outlined),
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
