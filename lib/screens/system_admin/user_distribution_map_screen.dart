import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/remote/system_admin_repository.dart';

enum _MapFilter { all, donor, organisation, hospital }

const _stateCentres = <String, LatLng>{
  'Johor': LatLng(1.4854, 103.7618),
  'Kedah': LatLng(6.1184, 100.3685),
  'Kelantan': LatLng(6.1254, 102.2381),
  'Melaka': LatLng(2.1896, 102.2501),
  'Negeri Sembilan': LatLng(2.7258, 101.9424),
  'Pahang': LatLng(3.8077, 103.3260),
  'Perak': LatLng(4.5975, 101.0901),
  'Perlis': LatLng(6.4449, 100.2048),
  'Pulau Pinang': LatLng(5.4141, 100.3288),
  'Sabah': LatLng(5.9804, 116.0735),
  'Sarawak': LatLng(1.5533, 110.3592),
  'Selangor': LatLng(3.0738, 101.5183),
  'Terengganu': LatLng(5.3296, 103.1370),
  'Kuala Lumpur': LatLng(3.1390, 101.6869),
  'Putrajaya': LatLng(2.9264, 101.6964),
  'Labuan': LatLng(5.2831, 115.2308),
};

class UserDistributionMapScreen extends StatefulWidget {
  const UserDistributionMapScreen({super.key});

  @override
  State<UserDistributionMapScreen> createState() =>
      _UserDistributionMapScreenState();
}

class _UserDistributionMapScreenState
    extends State<UserDistributionMapScreen> {
  final mapController = MapController();
  late Future<SystemUserDistribution> distribution = load();
  _MapFilter filter = _MapFilter.all;

  Future<SystemUserDistribution> load() {
    final client = SupabaseService.client;
    if (client == null) {
      return Future.error(StateError('Please log in again.'));
    }
    return SystemAdminRepository(client).getUserDistribution();
  }

  Future<void> refresh() async {
    final refreshed = load();
    setState(() => distribution = refreshed);
    await refreshed;
  }

  List<SystemInstitutionLocation> filtered(
    List<SystemInstitutionLocation> values,
  ) => switch (filter) {
    _MapFilter.all => values,
    _MapFilter.donor => const [],
    _MapFilter.organisation =>
      values.where((item) => !item.isHospital).toList(),
    _MapFilter.hospital => values.where((item) => item.isHospital).toList(),
  };

  void showDonorState(String state, int count) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.systemAdminBackground,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          leading: const Icon(Icons.people),
          title: Text(state, style: Theme.of(context).textTheme.titleLarge),
          subtitle: Text('$count registered donor${count == 1 ? '' : 's'}'),
        ),
      ),
    );
  }

  String stateFor(String? address) {
    final value = address?.toLowerCase() ?? '';
    const states = <String, String>{
      'johor': 'Johor',
      'kedah': 'Kedah',
      'kelantan': 'Kelantan',
      'melaka': 'Melaka',
      'malacca': 'Melaka',
      'negeri sembilan': 'Negeri Sembilan',
      'pahang': 'Pahang',
      'perak': 'Perak',
      'perlis': 'Perlis',
      'pulau pinang': 'Pulau Pinang',
      'penang': 'Pulau Pinang',
      'sabah': 'Sabah',
      'sarawak': 'Sarawak',
      'selangor': 'Selangor',
      'terengganu': 'Terengganu',
      'kuala lumpur': 'Kuala Lumpur',
      'putrajaya': 'Putrajaya',
      'labuan': 'Labuan',
    };
    for (final entry in states.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return 'Unspecified';
  }

  void showInstitution(SystemInstitutionLocation item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.systemAdminBackground,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(item.roleLabel),
              if (item.address case final address?) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(address)),
                  ],
                ),
              ],
              if (item.contactPhone case final phone?) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined),
                    const SizedBox(width: 8),
                    Text(phone),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.systemAdminBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.systemAdminHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
      title: const Text('User & institution map'),
    ),
    body: FutureBuilder<SystemUserDistribution>(
      future: distribution,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Unable to load map. Try again'),
            ),
          );
        }
        final value = snapshot.data!;
        final locations = filtered(value.institutions);
        final donorEntries = value.donorsByState.entries
            .where((entry) => _stateCentres.containsKey(entry.key))
            .toList();
        final showDonors = filter == _MapFilter.all || filter == _MapFilter.donor;
        final organisationCount = value.institutions
            .where((item) => !item.isHospital)
            .length;
        final hospitalCount = value.institutions
            .where((item) => item.isHospital)
            .length;
        final stateCounts = <String, int>{};
        for (final item in value.institutions) {
          final state = stateFor(item.address);
          stateCounts[state] = (stateCounts[state] ?? 0) + 1;
        }
        final stateEntries = stateCounts.entries.toList()
          ..sort((a, b) {
            final countOrder = b.value.compareTo(a.value);
            return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
          });
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(
                    icon: Icons.people_outline,
                    label: '${value.counts.donors} donors',
                  ),
                  _CountChip(
                    icon: Icons.event_available_outlined,
                    label: '${value.counts.admins} organisation admins',
                  ),
                  _CountChip(
                    icon: Icons.local_hospital_outlined,
                    label: '${value.counts.hospitals} hospitals',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.privacy_tip_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Donors are grouped by state. Exact home addresses and '
                          'individual donor locations are not collected or displayed.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: filter == _MapFilter.all,
                    onSelected: (_) => setState(() => filter = _MapFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('Donors (${value.counts.donors})'),
                    selected: filter == _MapFilter.donor,
                    onSelected: (_) =>
                        setState(() => filter = _MapFilter.donor),
                  ),
                  ChoiceChip(
                    label: Text('Organisations ($organisationCount)'),
                    selected: filter == _MapFilter.organisation,
                    onSelected: (_) =>
                        setState(() => filter = _MapFilter.organisation),
                  ),
                  ChoiceChip(
                    label: Text('Hospitals ($hospitalCount)'),
                    selected: filter == _MapFilter.hospital,
                    onSelected: (_) =>
                        setState(() => filter = _MapFilter.hospital),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 430,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    mapController: mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(4.2, 102.0),
                      initialZoom: 5.2,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mobile_asg',
                      ),
                      MarkerLayer(
                        markers: [
                          ...locations.map(
                              (item) => Marker(
                                point: LatLng(item.latitude!, item.longitude!),
                                width: 48,
                                height: 48,
                                child: Semantics(
                                  button: true,
                                  label: '${item.roleLabel}: ${item.displayName}',
                                  child: GestureDetector(
                                    onTap: () => showInstitution(item),
                                    child: Icon(
                                      item.isHospital
                                          ? Icons.local_hospital
                                          : Icons.business,
                                      size: 40,
                                      color: item.isHospital
                                          ? AppTheme.systemAdminHeader
                                          : AppTheme.systemAdmin,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (showDonors)
                            ...donorEntries.map(
                              (entry) => Marker(
                                point: _stateCentres[entry.key]!,
                                width: 54,
                                height: 54,
                                child: Semantics(
                                  button: true,
                                  label: '${entry.value} donors in ${entry.key}',
                                  child: GestureDetector(
                                    onTap: () =>
                                        showDonorState(entry.key, entry.value),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.systemAdminHeader,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            blurRadius: 6,
                                            color: Colors.black26,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (locations.isEmpty && !showDonors) ...[
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.location_off_outlined),
                    title: Text('No mapped institutions'),
                    subtitle: Text(
                      'Institution administrators must save a location in '
                      'their profile before it can appear here.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business, color: AppTheme.systemAdmin),
                  const SizedBox(width: 6),
                  const Text('Organisation'),
                  const SizedBox(width: 20),
                  Icon(Icons.local_hospital, color: AppTheme.systemAdminHeader),
                  const SizedBox(width: 6),
                  const Text('Hospital'),
                  const SizedBox(width: 20),
                  Icon(Icons.people, color: AppTheme.systemAdminHeader),
                  const SizedBox(width: 6),
                  const Text('Donors by state'),
                ],
              ),
              if (value.donorsByState.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Donors by state',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: (value.donorsByState.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map(
                          (entry) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.people_outline),
                            title: Text(entry.key),
                            trailing: Text(
                              '${entry.value}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (stateEntries.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Mapped institutions by state',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: stateEntries
                        .map(
                          (entry) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_city_outlined),
                            title: Text(entry.key),
                            trailing: Text(
                              '${entry.value}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
  );
}
