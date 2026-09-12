import 'package:flutter/material.dart';

import '../data/remote/supabase_service.dart';
import '../screens/about_us_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/login_screen.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({
    super.key,
    this.isSystemAdmin = false,
    this.useDonorColors = false,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
  });

  final bool isSystemAdmin;
  final bool useDonorColors;
  final bool useOrganisationColors;
  final bool useHospitalColors;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        if (!isSystemAdmin) ...[
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send feedback'),
            subtitle: const Text('Report a problem or share a suggestion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackScreen(
                  useDonorColors: useDonorColors,
                  useOrganisationColors: useOrganisationColors,
                  useHospitalColors: useHospitalColors,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About Us'),
          subtitle: Text(
            isSystemAdmin
                ? 'View and edit the About Us page'
                : 'Learn more about MyDarah',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AboutUsScreen(
                canEdit: isSystemAdmin,
                useDonorColors: useDonorColors,
                useOrganisationColors: useOrganisationColors,
                useHospitalColors: useHospitalColors,
                useSystemAdminColors: isSystemAdmin,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileLogoutButton extends StatefulWidget {
  const ProfileLogoutButton({super.key});

  @override
  State<ProfileLogoutButton> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends State<ProfileLogoutButton> {
  bool signingOut = false;

  Future<void> signOut() async {
    if (signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => signingOut = true);
    try {
      await SupabaseService.client?.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: signingOut ? 'Logging out…' : 'Log out',
    icon: const Icon(Icons.logout),
    onPressed: signingOut ? null : signOut,
  );
}
