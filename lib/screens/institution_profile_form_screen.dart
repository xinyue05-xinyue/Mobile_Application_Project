import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme/app_theme.dart';
import '../data/remote/organisation_profile_repository.dart';
import '../data/remote/official_centre_repository.dart';
import '../data/remote/supabase_service.dart';
import '../models/organisation_profile.dart';

class InstitutionProfileFormScreen extends StatefulWidget {
  const InstitutionProfileFormScreen({
    super.key,
    required this.roleLabel,
    this.profile,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
  });
  final String roleLabel;
  final OrganisationProfile? profile;
  final bool useOrganisationColors;
  final bool useHospitalColors;

  @override
  State<InstitutionProfileFormScreen> createState() =>
      _InstitutionProfileFormScreenState();
}

class _InstitutionProfileFormScreenState
    extends State<InstitutionProfileFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController descriptionController;
  Uint8List? imageBytes;
  String? imageExtension;
  bool saving = false;
  bool searchingLocation = false;
  LatLng? location;
  final mapController = MapController();
  Timer? addressDebounce;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profile?.displayName);
    phoneController = TextEditingController(text: widget.profile?.contactPhone);
    addressController = TextEditingController(text: widget.profile?.address);
    descriptionController = TextEditingController(
      text: widget.profile?.description,
    );
    if (widget.profile?.latitude != null && widget.profile?.longitude != null) {
      location = LatLng(widget.profile!.latitude!, widget.profile!.longitude!);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    mapController.dispose();
    addressDebounce?.cancel();
    super.dispose();
  }

  void addressChanged(String value) {
    addressDebounce?.cancel();
    if (value.trim().length < 5) return;
    addressDebounce = Timer(const Duration(milliseconds: 900), findAddress);
  }

  Future<void> findAddress() async {
    final query = addressController.text.trim();
    if (query.length < 5 || searchingLocation) return;
    setState(() => searchingLocation = true);
    try {
      final result = await OfficialCentreRepository().searchLocation(query);
      if (!mounted) return;
      final point = LatLng(result.latitude, result.longitude);
      setState(() => location = point);
      mapController.move(point, 16);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to locate address: $error')),
      );
    } finally {
      if (mounted) setState(() => searchingLocation = false);
    }
  }

  Future<void> pickImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    if (await file.length() > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be 5 MB or smaller.')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      imageBytes = bytes;
      imageExtension = file.name.split('.').last.toLowerCase();
    });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => saving = true);
    try {
      final repository = OrganisationProfileRepository(client);
      var imagePath = widget.profile?.imagePath;
      if (imageBytes case final bytes?) {
        imagePath = await repository.uploadImage(
          bytes,
          imageExtension ?? 'jpg',
        );
      }
      await repository.save(
        displayName: nameController.text.trim(),
        contactPhone: phoneController.text.trim(),
        address: addressController.text.trim(),
        description: descriptionController.text.trim(),
        imagePath: imagePath,
        latitude: location?.latitude,
        longitude: location?.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save profile: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
        title: Text('Edit ${widget.roleLabel} profile'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (imageBytes case final bytes?)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(bytes, height: 190, fit: BoxFit.cover),
              ),
            OutlinedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Choose profile cover image'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Organisation or hospital name is required.'
                  : null,
              decoration: InputDecoration(
                labelText: '${widget.roleLabel} name',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              onChanged: addressChanged,
              onFieldSubmitted: (_) => findAddress(),
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Address'),
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
                const Expanded(
                  child: Text(
                    'The map updates automatically after you enter the address.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
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
                              color: Colors.red,
                              size: 46,
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
            TextFormField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              style: widget.useHospitalColors
                  ? FilledButton.styleFrom(
                      backgroundColor: AppTheme.hospital,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.hospitalPalette[1],
                      disabledForegroundColor: AppTheme.hospitalHeader,
                    )
                  : null,
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
