import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme/app_theme.dart';
import '../data/remote/supabase_service.dart';
import '../models/organisation_profile.dart';

class InstitutionDetailsTile extends StatefulWidget {
  const InstitutionDetailsTile({
    super.key,
    required this.ownerId,
    required this.label,
    this.cachedName,
    this.useDonorColors = false,
  });
  final String? ownerId;
  final String label;
  final String? cachedName;
  final bool useDonorColors;
  @override
  State<InstitutionDetailsTile> createState() => _InstitutionDetailsTileState();
}

class _InstitutionDetailsTileState extends State<InstitutionDetailsTile> {
  late Future<OrganisationProfile?> profile = load();
  Future<OrganisationProfile?> load() async {
    final client = SupabaseService.client;
    if (client == null || widget.ownerId == null) return null;
    final row = await client
        .from('organisation_profiles')
        .select()
        .eq('owner_id', widget.ownerId!)
        .maybeSingle();
    return row == null ? null : OrganisationProfile.fromMap(row);
  }

  @override
  void didUpdateWidget(covariant InstitutionDetailsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) profile = load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrganisationProfile?>(
    future: profile,
    builder: (context, snapshot) {
      final value = snapshot.data;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.business_outlined),
        title: Text(widget.label),
        subtitle: Text(
          value?.displayName ??
              widget.cachedName ??
              'Institution details unavailable',
        ),
        trailing: value == null ? null : const Icon(Icons.chevron_right),
        onTap: value == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InstitutionPublicProfileScreen(
                    profile: value,
                    useDonorColors: widget.useDonorColors,
                  ),
                ),
              ),
      );
    },
  );
}

class InstitutionPublicProfileScreen extends StatelessWidget {
  const InstitutionPublicProfileScreen({
    super.key,
    required this.profile,
    this.useDonorColors = false,
  });
  final OrganisationProfile profile;
  final bool useDonorColors;
  Future<void> directions(BuildContext context) async {
    final destination = profile.latitude != null && profile.longitude != null
        ? '${profile.latitude},${profile.longitude}'
        : profile.address;
    if (destination == null || destination.trim().isEmpty) return;
    try {
      if (!await launchUrl(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': destination,
        }),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Map unavailable');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open directions.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: useDonorColors ? AppTheme.donorBackground : null,
    appBar: AppBar(
      backgroundColor: useDonorColors ? AppTheme.donorHeader : null,
      foregroundColor: useDonorColors ? Colors.white : null,
      titleTextStyle: useDonorColors ? AppTheme.donorHeaderTitleStyle : null,
      title: Text(profile.displayName),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.imagePath != null && SupabaseService.client != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              SupabaseService.client!.storage
                  .from('organisation-images')
                  .getPublicUrl(profile.imagePath!),
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ListTile(
          title: Text(profile.displayName),
          subtitle: Text(profile.description ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: const Text('Institution phone'),
          subtitle: Text(profile.contactPhone ?? 'Not provided'),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Address'),
          subtitle: Text(profile.address ?? 'Not provided'),
        ),
        if ((profile.latitude != null && profile.longitude != null) ||
            (profile.address?.trim().isNotEmpty ?? false))
          OutlinedButton.icon(
            style: useDonorColors
                ? AppTheme.donorMutedOutlinedButtonStyle
                : null,
            onPressed: () => directions(context),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Open directions'),
          ),
      ],
    ),
  );
}
