import 'package:flutter/material.dart';
import '../app/theme/app_theme.dart';
import '../widgets/profile_actions.dart';

import '../data/remote/organisation_profile_repository.dart';
import '../data/remote/supabase_service.dart';
import '../models/organisation_profile.dart';
import 'institution_profile_form_screen.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({
    super.key,
    required this.roleLabel,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
  });
  final String roleLabel;
  final bool useOrganisationColors;
  final bool useHospitalColors;

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late Future<OrganisationProfile?> profile;

  @override
  void initState() {
    super.initState();
    profile = loadProfile();
    OrganisationProfileRepository.revision.addListener(profileChanged);
  }

  @override
  void dispose() {
    OrganisationProfileRepository.revision.removeListener(profileChanged);
    super.dispose();
  }

  void profileChanged() {
    if (!mounted) return;
    setState(refresh);
  }

  Future<OrganisationProfile?> loadProfile() {
    final client = SupabaseService.client;
    if (client == null) throw StateError('Supabase is not configured.');
    return OrganisationProfileRepository(client).getMine();
  }

  void refresh() => profile = loadProfile();

  Future<void> edit(OrganisationProfile? value) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InstitutionProfileFormScreen(
          roleLabel: widget.roleLabel,
          profile: value,
          useOrganisationColors: widget.useOrganisationColors,
          useHospitalColors: widget.useHospitalColors,
        ),
      ),
    );
    if (updated == true && mounted) setState(refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.useOrganisationColors
          ? AppTheme.organisationBackground
          : widget.useHospitalColors
          ? AppTheme.hospitalBackground
          : null,
      appBar: AppBar(
        backgroundColor: widget.useOrganisationColors
            ? AppTheme.organisationHeader
            : widget.useHospitalColors
            ? AppTheme.hospitalHeader
            : null,
        foregroundColor:
            widget.useOrganisationColors || widget.useHospitalColors
            ? Colors.white
            : null,
        titleTextStyle: widget.useOrganisationColors
            ? AppTheme.organisationHeaderTitleStyle
            : widget.useHospitalColors
            ? AppTheme.hospitalHeaderTitleStyle
            : null,
        automaticallyImplyLeading: false,
        title: Text('${widget.roleLabel} Profile'),
        actions: const [ProfileLogoutButton()],
      ),
      body: FutureBuilder<OrganisationProfile?>(
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
                ProfileActions(
                  useOrganisationColors: widget.useOrganisationColors,
                  useHospitalColors: widget.useHospitalColors,
                ),
              ],
            );
          }
          final value = snapshot.data;
          final imageUrl = value?.imagePath == null
              ? null
              : SupabaseService.client?.storage
                    .from('organisation-images')
                    .getPublicUrl(value!.imagePath!);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        height: 210,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 150,
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.business_outlined, size: 64),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            value?.displayName ?? 'Complete your profile',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(widget.roleLabel),
                          if (value?.description case final description?) ...[
                            const SizedBox(height: 10),
                            Text(description, textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Contact phone'),
                      subtitle: Text(value?.contactPhone ?? 'Not set'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Address'),
                      subtitle: Text(value?.address ?? 'Not set'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => edit(value),
                style: widget.useHospitalColors
                    ? FilledButton.styleFrom(
                        backgroundColor: AppTheme.hospital,
                        foregroundColor: Colors.white,
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit institutional profile'),
              ),
              const SizedBox(height: 24),
              ProfileActions(
                useOrganisationColors: widget.useOrganisationColors,
                useHospitalColors: widget.useHospitalColors,
              ),
            ],
          );
        },
      ),
    );
  }
}
