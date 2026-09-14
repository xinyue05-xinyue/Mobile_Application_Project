import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/admin_centre_repository.dart';
import '../../data/remote/official_centre_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';
import '../../models/donation_centre.dart';
import '../../widgets/location_suggestions.dart';

class CentreFormScreen extends StatefulWidget {
  const CentreFormScreen({super.key, this.centre});

  final DonationCentre? centre;

  @override
  State<CentreFormScreen> createState() => _CentreFormScreenState();
}

class _CentreFormScreenState extends State<CentreFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController stateController;
  late final TextEditingController latitudeController;
  late final TextEditingController longitudeController;
  late final TextEditingController hoursController;
  bool isSaving = false;
  LatLng? selectedLocation;
  final mapController = MapController();
  bool searchingLocation = false;
  final addressFocusNode = FocusNode();
  final officialRepository = OfficialCentreRepository();
  List<DonationCentre> officialCentres = const [];
  List<LocationSearchResult> locationSuggestions = const [];
  bool savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    final centre = widget.centre;
    nameController = TextEditingController(text: centre?.name);
    addressController = TextEditingController(text: centre?.address);
    stateController = TextEditingController(text: centre?.state);
    latitudeController = TextEditingController(
      text: centre?.latitude.toString(),
    );
    longitudeController = TextEditingController(
      text: centre?.longitude.toString(),
    );
    hoursController = TextEditingController(text: centre?.operatingHours);
    if (centre != null) {
      selectedLocation = LatLng(centre.latitude, centre.longitude);
    }
    loadOfficialCentres();
    restoreDraft();
  }

  String get draftName => 'venue_draft_${widget.centre?.id ?? 'new'}';

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(userId, draftName);
    if (!mounted || draft == null) return;
    setState(() {
      nameController.text = draft['name'] as String? ?? nameController.text;
      addressController.text =
          draft['address'] as String? ?? addressController.text;
      stateController.text = draft['state'] as String? ?? stateController.text;
      latitudeController.text =
          draft['latitude'] as String? ?? latitudeController.text;
      longitudeController.text =
          draft['longitude'] as String? ?? longitudeController.text;
      hoursController.text =
          draft['operating_hours'] as String? ?? hoursController.text;
      final latitude = double.tryParse(latitudeController.text);
      final longitude = double.tryParse(longitudeController.text);
      if (latitude != null && longitude != null) {
        selectedLocation = LatLng(latitude, longitude);
      }
    });
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance.saveMap(userId, draftName, {
      'name': nameController.text,
      'address': addressController.text,
      'state': stateController.text,
      'latitude': latitudeController.text,
      'longitude': longitudeController.text,
      'operating_hours': hoursController.text,
    });
  }

  Future<void> loadOfficialCentres() async {
    final result = await officialRepository.loadCentres();
    if (!mounted) return;
    setState(() => officialCentres = result.centres);
  }

  void selectLocation(LatLng point) {
    setState(() {
      selectedLocation = point;
      latitudeController.text = point.latitude.toStringAsFixed(6);
      longitudeController.text = point.longitude.toStringAsFixed(6);
    });
  }

  @override
  void dispose() {
    if (!savedSuccessfully) saveDraft();
    nameController.dispose();
    addressController.dispose();
    stateController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    hoursController.dispose();
    mapController.dispose();
    addressFocusNode.dispose();
    super.dispose();
  }

  Iterable<DonationCentre> matchingCentres(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.length < 2) return const Iterable<DonationCentre>.empty();
    return officialCentres
        .where(
          (centre) =>
              centre.name.toLowerCase().contains(query) ||
              centre.state.toLowerCase().contains(query),
        )
        .take(6);
  }

  Future<void> selectOfficialCentre(DonationCentre centre) async {
    addressFocusNode.unfocus();
    nameController.text = centre.name;
    stateController.text = centre.state;
    addressController.text = centre.name;
    final point = LatLng(centre.latitude, centre.longitude);
    selectLocation(point);
    mapController.move(point, 16);

    setState(() => searchingLocation = true);
    final address = await officialRepository.getAddress(centre);
    if (!mounted) return;
    addressController.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );
    setState(() => searchingLocation = false);
  }

  Future<void> findAddress() async {
    final state = stateController.text.trim();
    final queries = <String>{
      _normaliseLocationQuery(
        [
          addressController.text.trim(),
          state,
        ].where((value) => value.isNotEmpty).join(', '),
      ),
      _normaliseLocationQuery(
        [
          nameController.text.trim(),
          state,
        ].where((value) => value.isNotEmpty).join(', '),
      ),
    }.where((value) => value.length >= 3).toList();
    if (queries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the centre address first.')),
      );
      return;
    }
    setState(() => searchingLocation = true);
    try {
      List<LocationSearchResult> results = const [];
      for (final query in queries) {
        try {
          results = await officialRepository.searchLocations(query);
          if (results.isNotEmpty) break;
        } on Exception {
          continue;
        }
      }
      if (!mounted) return;
      if (results.isEmpty) throw StateError('Location not found.');
      setState(() => locationSuggestions = results);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No matching location found. Try a broader place name, for example "TAR UMT Kuala Lumpur".',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => searchingLocation = false);
    }
  }

  String _normaliseLocationQuery(String value) =>
      value.replaceAll(RegExp(r'\btarumt\b', caseSensitive: false), 'TAR UMT');

  void selectLocationSuggestion(LocationSearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    addressController.value = TextEditingValue(
      text: result.address,
      selection: TextSelection.collapsed(offset: result.address.length),
    );
    setState(() => locationSuggestions = const []);
    selectLocation(point);
    mapController.move(point, 16);
    addressFocusNode.unfocus();
  }

  String? requiredValue(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field.' : null;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid address and wait for the map to update.',
          ),
        ),
      );
      return;
    }
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => isSaving = true);
    try {
      final repository = AdminCentreRepository(client);
      final centre = widget.centre;
      final values = (
        name: nameController.text.trim(),
        address: addressController.text.trim(),
        state: stateController.text.trim(),
        latitude: double.parse(latitudeController.text),
        longitude: double.parse(longitudeController.text),
        hours: hoursController.text.trim(),
      );
      if (centre == null) {
        await repository.create(
          name: values.name,
          address: values.address,
          state: values.state,
          latitude: values.latitude,
          longitude: values.longitude,
          operatingHours: values.hours,
        );
      } else {
        await repository.update(
          id: centre.id,
          name: values.name,
          address: values.address,
          state: values.state,
          latitude: values.latitude,
          longitude: values.longitude,
          operatingHours: values.hours,
        );
      }
      await LocalCacheService.instance.remove(
        client.auth.currentUser!.id,
        draftName,
      );
      savedSuccessfully = true;
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.organisationBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.organisationHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.organisationHeaderTitleStyle,
        title: Text(
          widget.centre == null ? 'Add event venue' : 'Edit event venue',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _TextField(
              controller: nameController,
              label: 'Centre name',
              validator: requiredValue,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RawAutocomplete<DonationCentre>(
                textEditingController: addressController,
                focusNode: addressFocusNode,
                displayStringForOption: (centre) => centre.name,
                optionsBuilder: matchingCentres,
                onSelected: selectOfficialCentre,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) =>
                        TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          validator: requiredValue,
                          onChanged: (_) {
                            if (locationSuggestions.isNotEmpty) {
                              setState(() => locationSuggestions = const []);
                            }
                          },
                          onFieldSubmitted: (_) => findAddress(),
                          decoration: InputDecoration(
                            labelText: 'Address or location name',
                            suffixIcon: IconButton(
                              tooltip: 'Search address',
                              onPressed: searchingLocation ? null : findAddress,
                              icon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width - 48,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final centre = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(
                                Icons.local_hospital_outlined,
                              ),
                              title: Text(centre.name),
                              subtitle: Text(centre.state),
                              onTap: () => onSelected(centre),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (locationSuggestions.isNotEmpty)
              LocationSuggestions(
                results: locationSuggestions,
                onSelected: selectLocationSuggestion,
              ),
            _TextField(
              controller: stateController,
              label: 'State',
              validator: requiredValue,
            ),
            Text(
              'Centre location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Type and select an official hospital, or enter any school, mall, '
              'hall or full address and press search. Choose the correct result.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (searchingLocation)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.location_searching, size: 18),
                const SizedBox(width: 8),
                Text(
                  searchingLocation ? 'Locating address…' : 'Address location',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter:
                        selectedLocation ?? const LatLng(3.139, 101.6869),
                    initialZoom: selectedLocation == null ? 11 : 15,
                    onTap: (_, point) => selectLocation(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile_asg',
                    ),
                    if (selectedLocation case final point?)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_on,
                              size: 46,
                              color: Colors.red,
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
            const SizedBox(height: 12),
            _TextField(controller: hoursController, label: 'Operating hours'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isSaving ? null : save,
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save event venue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
