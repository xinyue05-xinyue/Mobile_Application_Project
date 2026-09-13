import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../widgets/profile_actions.dart';

import '../../data/remote/profile_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/donor_profile.dart';

class SystemAdminProfileScreen extends StatefulWidget {
  const SystemAdminProfileScreen({super.key});

  @override
  State<SystemAdminProfileScreen> createState() =>
      _SystemAdminProfileScreenState();
}

class _SystemAdminProfileScreenState extends State<SystemAdminProfileScreen> {
  late Future<DonorProfile> profile;

  @override
  void initState() {
    super.initState();
    profile = loadProfile();
  }

  Future<DonorProfile> loadProfile() {
    final client = SupabaseService.client;
    if (client == null) throw StateError('Supabase is not configured.');
    return ProfileRepository(client).getCurrentProfile();
  }

  Future<void> edit(DonorProfile current) async {
    final name = TextEditingController(text: current.fullName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit administrator profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        final client = SupabaseService.client!;
        await ProfileRepository(
          client,
        ).updateBasicProfile(fullName: name.text.trim());
        if (mounted) {
          setState(() {
            profile = loadProfile();
          });
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to save profile. Please try again.'),
            ),
          );
        }
      }
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.client?.auth.currentUser?.email ?? 'Not set';
    return Scaffold(
      backgroundColor: AppTheme.systemAdminBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.systemAdminHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
        automaticallyImplyLeading: false,
        title: const Text('Administrator profile'),
        actions: const [ProfileLogoutButton()],
      ),
      body: FutureBuilder<DonorProfile>(
        future: profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Unable to load profile. Please try again.'),
                const ProfileActions(isSystemAdmin: true),
              ],
            );
          }
          final value = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        child: Icon(Icons.admin_panel_settings, size: 42),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value.fullName,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const Text('System administrator'),
                      const SizedBox(height: 6),
                      Text(email, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => edit(value),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 24),
              const ProfileActions(isSystemAdmin: true),
            ],
          );
        },
      ),
    );
  }
}
