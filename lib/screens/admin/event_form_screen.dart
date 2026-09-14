import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../app/theme/app_theme.dart';
import '../../data/remote/admin_centre_repository.dart';
import '../../data/remote/admin_event_repository.dart';
import '../../data/remote/official_centre_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';
import '../../models/donation_centre.dart';
import '../../models/donation_event.dart';
import '../../widgets/location_suggestions.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final DonationEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController venueController;
  late final TextEditingController descriptionController;
  late DateTime startsAt;
  late DateTime endsAt;
  late DateTime publishAt;
  bool isSaving = false;
  LatLng? location;
  Uint8List? imageBytes;
  String? imageExtension;
  String? imageName;
  final mapController = MapController();
  bool searchingLocation = false;
  final venueFocusNode = FocusNode();
  List<DonationCentre> officialCentres = const [];
  List<DonationCentre> organisationVenues = const [];
  List<LocationSearchResult> locationSuggestions = const [];
  bool savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final defaultStart = DateTime.now().add(const Duration(days: 7));
    titleController = TextEditingController(text: event?.title);
    venueController = TextEditingController(text: event?.venue);
    descriptionController = TextEditingController(text: event?.description);
    startsAt = event?.startsAt ?? defaultStart;
    endsAt = event?.endsAt ?? defaultStart.add(const Duration(hours: 5));
    publishAt = event?.publishAt ?? DateTime.now();
    if (event?.latitude != null && event?.longitude != null) {
      location = LatLng(event!.latitude!, event.longitude!);
    }
    loadVenueSuggestions();
    restoreDraft();
  }

  String get draftName => 'event_draft_${widget.event?.id ?? 'new'}';

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(userId, draftName);
    if (!mounted || draft == null) return;
    final latitude = draft['latitude'] as num?;
    final longitude = draft['longitude'] as num?;
    setState(() {
      titleController.text = draft['title'] as String? ?? titleController.text;
      venueController.text = draft['venue'] as String? ?? venueController.text;
      descriptionController.text =
          draft['description'] as String? ?? descriptionController.text;
      startsAt =
          DateTime.tryParse(draft['starts_at'] as String? ?? '')?.toLocal() ??
          startsAt;
      endsAt =
          DateTime.tryParse(draft['ends_at'] as String? ?? '')?.toLocal() ??
          endsAt;
      publishAt =
          DateTime.tryParse(draft['publish_at'] as String? ?? '')?.toLocal() ??
          publishAt;
      if (latitude != null && longitude != null) {
        location = LatLng(latitude.toDouble(), longitude.toDouble());
      }
    });
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance.saveMap(userId, draftName, {
      'title': titleController.text,
      'venue': venueController.text,
      'description': descriptionController.text,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'publish_at': publishAt.toUtc().toIso8601String(),
      'latitude': location?.latitude,
      'longitude': location?.longitude,
    });
  }

  Future<void> loadVenueSuggestions() async {
    final client = SupabaseService.client;
    final results = await Future.wait([
      OfficialCentreRepository().loadCentres(),
      if (client != null)
        AdminCentreRepository(client).getCentres()
      else
        Future.value(const <DonationCentre>[]),
    ]);
    if (!mounted) return;
    setState(() {
      officialCentres = (results[0] as OfficialCentreResult).centres;
      organisationVenues = results[1] as List<DonationCentre>;
    });
  }

  Future<void> chooseImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty || !mounted) return;
    final file = result.single;
    final size = await file.length();
    if (!mounted) return;
    if (size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event image must be 5 MB or smaller.')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      imageBytes = bytes;
      imageExtension = extension;
      imageName = file.name;
    });
  }

  String? publicImageUrl(String path) =>
      SupabaseService.client?.storage.from('event-images').getPublicUrl(path);

  @override
  void dispose() {
    if (!savedSuccessfully) saveDraft();
    titleController.dispose();
    venueController.dispose();
    descriptionController.dispose();
    mapController.dispose();
    venueFocusNode.dispose();
    super.dispose();
  }

  Iterable<DonationCentre> matchingCentres(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.length < 2) return const Iterable<DonationCentre>.empty();
    final matches = [...organisationVenues, ...officialCentres].where(
      (centre) =>
          centre.name.toLowerCase().contains(query) ||
          centre.address.toLowerCase().contains(query) ||
          centre.state.toLowerCase().contains(query),
    );
    return matches.take(6);
  }

  void selectOfficialCentre(DonationCentre centre) {
    final point = LatLng(centre.latitude, centre.longitude);
    venueController.value = TextEditingValue(
      text: centre.name,
      selection: TextSelection.collapsed(offset: centre.name.length),
    );
    setState(() => location = point);
    mapController.move(point, 16);
    venueFocusNode.unfocus();
  }

  Future<void> findVenue() async {
    final query = venueController.text.trim();
    if (query.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue or address first.')),
      );
      return;
    }
    setState(() => searchingLocation = true);
    try {
      final results = await OfficialCentreRepository().searchLocations(query);
      if (!mounted) return;
      if (results.isEmpty) throw StateError('Location not found.');
      setState(() => locationSuggestions = results);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No matching location found. Try the official place name and city or state.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => searchingLocation = false);
    }
  }

  void selectLocationSuggestion(LocationSearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    venueController.value = TextEditingValue(
      text: result.address,
      selection: TextSelection.collapsed(offset: result.address.length),
    );
    setState(() {
      locationSuggestions = const [];
      location = point;
    });
    mapController.move(point, 16);
    venueFocusNode.unfocus();
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  Future<DateTime?> chooseDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!endsAt.isAfter(startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    if (publishAt.isAfter(startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The event must be published before it starts.'),
        ),
      );
      return;
    }
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to set the event location.')),
      );
      return;
    }
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => isSaving = true);
    try {
      final repository = AdminEventRepository(client);
      final event = widget.event;
      var imagePath = event?.imagePath;
      if (imageBytes case final bytes?) {
        imagePath = await repository.uploadImage(
          bytes: bytes,
          extension: imageExtension ?? 'jpg',
        );
      }
      if (event == null) {
        await repository.create(
          title: titleController.text.trim(),
          venue: venueController.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          description: descriptionController.text.trim(),
          latitude: location!.latitude,
          longitude: location!.longitude,
          imagePath: imagePath,
          publishAt: publishAt,
        );
      } else {
        await repository.update(
          id: event.id,
          title: titleController.text.trim(),
          venue: venueController.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          description: descriptionController.text.trim(),
          latitude: location!.latitude,
          longitude: location!.longitude,
          imagePath: imagePath,
          publishAt: publishAt,
        );
      }
      await LocalCacheService.instance.remove(
        client.auth.currentUser!.id,
        draftName,
      );
      savedSuccessfully = true;
      if (!mounted) return;
      Navigator.pop(context, true);
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
        title: Text(widget.event == null ? 'Create event' : 'Edit event'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: titleController,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Event title'),
            ),
            const SizedBox(height: 16),
            RawAutocomplete<DonationCentre>(
              textEditingController: venueController,
              focusNode: venueFocusNode,
              displayStringForOption: (centre) => centre.name,
              optionsBuilder: matchingCentres,
              onSelected: selectOfficialCentre,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        validator: _required,
                        onChanged: (_) {
                          if (locationSuggestions.isNotEmpty) {
                            setState(() => locationSuggestions = const []);
                          }
                        },
                        onFieldSubmitted: (_) => findVenue(),
                        decoration: InputDecoration(
                          labelText: 'Venue or full address',
                          suffixIcon: IconButton(
                            tooltip: 'Search address',
                            onPressed: searchingLocation ? null : findVenue,
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
                            leading: Icon(
                              centre.sourceId == null
                                  ? Icons.location_on_outlined
                                  : Icons.local_hospital_outlined,
                            ),
                            title: Text(centre.name),
                            subtitle: Text(
                              centre.sourceId == null
                                  ? '${centre.address}\nOrganisation event venue'
                                  : '${centre.state}\nOfficial donation centre',
                            ),
                            isThreeLine: true,
                            onTap: () => onSelected(centre),
                          );
                        },
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
            const SizedBox(height: 16),
            Text(
              'Event location',
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
                Text(searchingLocation ? 'Locating venue…' : 'Venue location'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: location ?? const LatLng(3.139, 101.6869),
                    initialZoom: location == null ? 11 : 15,
                    onTap: (_, point) => setState(() => location = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile_asg',
                    ),
                    if (location case final point?)
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
            if (location case final point?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Selected: ${point.latitude.toStringAsFixed(6)}, '
                  '${point.longitude.toStringAsFixed(6)}',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Event image (optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (imageBytes case final bytes?)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(bytes, height: 180, fit: BoxFit.cover),
              )
            else if (widget.event?.imagePath case final path?)
              if (publicImageUrl(path) case final url?)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(url, height: 180, fit: BoxFit.cover),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: chooseImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(imageName ?? 'Choose JPG, PNG or WebP image'),
            ),
            const SizedBox(height: 16),
            _DateTile(
              label: 'Publish event',
              value: dateLabel(publishAt),
              icon: Icons.schedule_send_outlined,
              onTap: () async {
                final value = await chooseDateTime(publishAt);
                if (value != null) setState(() => publishAt = value);
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Donors will see the event and receive the in-app event notification from this time.',
              ),
            ),
            const SizedBox(height: 16),
            _DateTile(
              label: 'Starts',
              value: dateLabel(startsAt),
              onTap: () async {
                final value = await chooseDateTime(startsAt);
                if (value != null) setState(() => startsAt = value);
              },
            ),
            const SizedBox(height: 12),
            _DateTile(
              label: 'Ends',
              value: dateLabel(endsAt),
              onTap: () async {
                final value = await chooseDateTime(endsAt);
                if (value != null) setState(() => endsAt = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSaving ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.organisation,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.organisationPalette[1],
                disabledForegroundColor: AppTheme.organisationHeader,
              ),
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.event == null ? 'Create event' : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field.' : null;
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.event_outlined,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}
