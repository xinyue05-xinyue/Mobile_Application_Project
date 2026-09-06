import 'package:flutter/material.dart';

import '../data/remote/organisation_profile_repository.dart';
import '../data/remote/supabase_service.dart';

class SignedInIdentityCard extends StatefulWidget {
  const SignedInIdentityCard({
    super.key,
    required this.roleLabel,
    this.useInstitutionProfile = false,
  });

  final String roleLabel;
  final bool useInstitutionProfile;

  @override
  State<SignedInIdentityCard> createState() => _SignedInIdentityCardState();
}

class _SignedInIdentityCardState extends State<SignedInIdentityCard> {
  late Future<String?> profileName;

  @override
  void initState() {
    super.initState();
    profileName = _loadName();
    OrganisationProfileRepository.revision.addListener(_profileChanged);
  }

  @override
  void dispose() {
    OrganisationProfileRepository.revision.removeListener(_profileChanged);
    super.dispose();
  }

  void _profileChanged() {
    if (!mounted || !widget.useInstitutionProfile) return;
    setState(() => profileName = _loadName());
  }

  Future<String?> _loadName() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    if (widget.useInstitutionProfile) {
      final profile = await OrganisationProfileRepository(client).getMine();
      return profile?.displayName;
    }
    final row = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
    return row?['full_name'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: profileName,
      builder: (context, snapshot) {
        final user = SupabaseService.client?.auth.currentUser;
        final name = snapshot.data;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                (name?.trim().isNotEmpty ?? false)
                    ? name!.trim()[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(
              snapshot.connectionState != ConnectionState.done
                  ? 'Loading account…'
                  : name ?? 'Signed-in user',
            ),
            subtitle: Text('${widget.roleLabel}\n${user?.email ?? ''}'),
            isThreeLine: true,
            trailing: const Icon(Icons.verified_user_outlined),
          ),
        );
      },
    );
  }
}
