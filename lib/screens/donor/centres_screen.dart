import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/official_centre_repository.dart';
import '../../data/repositories/data_sync_service.dart';
import '../../data/repositories/government_data_repository.dart';
import '../../models/donation_centre.dart';
import '../../models/government_donation_stat.dart';

class CentresScreen extends StatefulWidget {
  const CentresScreen({super.key});

  @override
  State<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends State<CentresScreen> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final syncService = DataSyncService();
  final governmentRepository = GovernmentDataRepository();
  final officialRepository = OfficialCentreRepository();
  final mapController = MapController();
  final addressCache = <String, Future<String>>{};
  late Future<_CentreData> data;
  DonationCentre? selectedCentre;
  Position? userPosition;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<_CentreData> loadData() async {
    final results = await Future.wait([
      syncService.loadCentres(),
      governmentRepository.loadRecentStats(),
      _loadOfficialCentres(),
    ]);
    final managed = results[0] as List<DonationCentre>;
    final officialResult = results[2] as OfficialCentreResult;
    final official = officialResult.centres;
    final byName = <String, DonationCentre>{
      for (final centre in official) centre.name.toLowerCase(): centre,
      for (final centre in managed) centre.name.toLowerCase(): centre,
    };
    return _CentreData(
      byName.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
      results[1] as List<GovernmentDonationStat>,
      official.isNotEmpty,
      officialResult.isFromCache && official.isNotEmpty,
    );
  }

  Future<OfficialCentreResult> _loadOfficialCentres() {
    return officialRepository.loadCentres();
  }

  void showCentre(DonationCentre centre) {
    mapController.move(LatLng(centre.latitude, centre.longitude), 14);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.donorBackground,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder<String>(
          future: _addressFor(centre),
          builder: (context, snapshot) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_hospital_outlined),
                title: Text(centre.name),
                subtitle: Text(
                  snapshot.connectionState != ConnectionState.done
                      ? 'Finding address…\n${centre.state}'
                      : '${snapshot.data ?? centre.address}\n${centre.state}'
                            '${distanceLabel(centre) == null ? '' : '\n${distanceLabel(centre)} away'}',
                ),
                isThreeLine: true,
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => openDirections(centre),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Open directions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _addressFor(DonationCentre centre) {
    if (!centre.id.startsWith('kkm-')) return Future.value(centre.address);
    return addressCache.putIfAbsent(
      centre.id,
      () => officialRepository.getAddress(centre),
    );
  }

  List<DonationCentre> displayedCentres(List<DonationCentre> centres) {
    final matches = selectedCentre == null
        ? centres.toList()
        : <DonationCentre>[selectedCentre!];
    if (userPosition != null) {
      matches.sort(
        (first, second) => distanceTo(first).compareTo(distanceTo(second)),
      );
    }
    return matches;
  }

  Iterable<DonationCentre> centreSuggestions(
    TextEditingValue value,
    List<DonationCentre> centres,
  ) {
    final search = value.text.trim().toLowerCase();
    if (search.isEmpty) return const Iterable<DonationCentre>.empty();
    return centres.where((centre) {
      return centre.name.toLowerCase().contains(search) ||
          centre.address.toLowerCase().contains(search) ||
          centre.state.toLowerCase().contains(search);
    }).take(6);
  }

  double distanceTo(DonationCentre centre) {
    final position = userPosition;
    if (position == null) return double.infinity;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          centre.latitude,
          centre.longitude,
        ) /
        1000;
  }

  String? distanceLabel(DonationCentre centre) {
    if (userPosition == null) return null;
    final distance = distanceTo(centre);
    return distance < 1
        ? '${(distance * 1000).round()} m'
        : '${distance.toStringAsFixed(1)} km';
  }

  Future<void> findNearest() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is required to find nearby centres.',
            ),
            action: permission == LocationPermission.deniedForever
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: Geolocator.openAppSettings,
                  )
                : null,
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => userPosition = position);
      mapController.move(LatLng(position.latitude, position.longitude), 10);
    } on LocationServiceDisabledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Turn on device location and try again.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openLocationSettings,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get your location: $error')),
      );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> openDirections(DonationCentre centre) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${centre.latitude},${centre.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open map directions.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        automaticallyImplyLeading: false,
        title: const Text('Where to donate'),
      ),
      body: FutureBuilder<_CentreData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load data: ${snapshot.error}'),
            );
          }
          final value =
              snapshot.data ?? const _CentreData([], [], false, false);
          final centres = displayedCentres(value.centres);
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              data = loadData();
            }),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _GovernmentActivityCard(stats: value.stats),
                const SizedBox(height: 16),
                if (!value.officialAvailable) ...[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Official facility map is unavailable'),
                      subtitle: Text(
                        'Deploy the donation-centres Supabase function, then pull down to retry.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (value.officialFromCache) ...[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.offline_pin_outlined),
                      title: Text('Showing cached official facilities'),
                      subtitle: Text(
                        'Connect to the internet and pull down to check for updates.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                RawAutocomplete<DonationCentre>(
                  textEditingController: searchController,
                  focusNode: searchFocusNode,
                  displayStringForOption: (centre) => centre.name,
                  optionsBuilder: (text) => centreSuggestions(
                    text,
                    value.centres,
                  ),
                  onSelected: (centre) {
                    setState(() => selectedCentre = centre);
                    searchFocusNode.unfocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) showCentre(centre);
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) =>
                          TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (_) {
                              if (selectedCentre != null) {
                                setState(() => selectedCentre = null);
                              }
                            },
                            onSubmitted: (_) => onSubmitted(),
                            decoration: const InputDecoration(
                              labelText:
                                  'Search facilities and event venues',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                  optionsViewBuilder: (context, onSelected, options) {
                    final matches = options.toList();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 32,
                            maxHeight: 330,
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final centre = matches[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.local_hospital_outlined,
                                  color: AppTheme.donor,
                                ),
                                title: Text(centre.name),
                                subtitle: Text(
                                  '${centre.address}\n${centre.state}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => onSelected(centre),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: AppTheme.donorMutedOutlinedButtonStyle,
                  onPressed: locating ? null : findNearest,
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    userPosition == null
                        ? 'Find centres near me'
                        : 'Centres sorted by nearest',
                  ),
                ),
                const SizedBox(height: 16),
                if (centres.isNotEmpty) ...[
                  SizedBox(
                    height: 320,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                              ...centres.map(
                                (centre) => Marker(
                                  point: LatLng(
                                    centre.latitude,
                                    centre.longitude,
                                  ),
                                  width: 46,
                                  height: 46,
                                  child: GestureDetector(
                                    onTap: () => showCentre(centre),
                                    child: Icon(
                                      Icons.location_on,
                                      size: 42,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              if (userPosition case final position?)
                                Marker(
                                  point: LatLng(
                                    position.latitude,
                                    position.longitude,
                                  ),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(
                                    Icons.my_location,
                                    size: 34,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (centres.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No matching donation locations.'),
                      subtitle: Text(
                        'Centre records can be added by an organisation admin.',
                      ),
                    ),
                  )
                else
                  ...centres.map(
                    (centre) => Card(
                      child: ListTile(
                        onTap: () => showCentre(centre),
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: const Icon(Icons.local_hospital_outlined),
                        ),
                        title: Text(centre.name),
                        subtitle: Text(
                          '${centre.sourceId == null ? 'Organisation event venue' : 'Official BBISv2 collection facility'}\n'
                          '${centre.address}\n${centre.state}'
                          '${centre.operatingHours == null ? '' : '\n${centre.operatingHours}'}'
                          '${distanceLabel(centre) == null ? '' : '\n${distanceLabel(centre)} away'}',
                        ),
                        isThreeLine: true,
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

class _GovernmentActivityCard extends StatelessWidget {
  const _GovernmentActivityCard({required this.stats});

  final List<GovernmentDonationStat> stats;

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Government donation activity unavailable'),
          subtitle: Text('Connect to the internet to retrieve official data.'),
        ),
      );
    }

    final latestDate = stats
        .map((stat) => stat.date)
        .reduce((first, second) => first.isAfter(second) ? first : second);
    final latest = stats
        .where(
          (stat) =>
              stat.date.year == latestDate.year &&
              stat.date.month == latestDate.month &&
              stat.date.day == latestDate.day,
        )
        .toList();
    final total = latest
        .where((stat) => stat.bloodType == 'all')
        .fold<int>(0, (sum, stat) => sum + stat.donations);
    final groupTotals = <String, int>{};
    for (final stat in latest.where((stat) => stat.bloodType != 'all')) {
      groupTotals.update(
        stat.bloodType,
        (value) => value + stat.donations,
        ifAbsent: () => stat.donations,
      );
    }
    final groups = groupTotals.entries
        .map((entry) => '${entry.key.toUpperCase()}: ${entry.value}')
        .join('  •  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Malaysia blood donation activity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$total donations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Data date: ${dateLabel(latestDate)}'),
            if (groups.isNotEmpty) ...[const SizedBox(height: 8), Text(groups)],
            const SizedBox(height: 12),
            const Text(
              'Source: National Blood Centre and Ministry of Health Malaysia via data.gov.my. The dataset covers 22 main BBISv2 collection sites.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentreData {
  const _CentreData(
    this.centres,
    this.stats,
    this.officialAvailable,
    this.officialFromCache,
  );

  final List<DonationCentre> centres;
  final List<GovernmentDonationStat> stats;
  final bool officialAvailable;
  final bool officialFromCache;
}
