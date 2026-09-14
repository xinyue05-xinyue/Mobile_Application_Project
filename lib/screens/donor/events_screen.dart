import 'package:flutter/material.dart';
import '../../widgets/event_schedule.dart';
import '../../widgets/institution_details_tile.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../data/local/event_reminder_service.dart';
import '../../data/remote/event_registration_repository.dart';
import '../../data/remote/profile_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repositories/data_sync_service.dart';
import '../../models/donation_event.dart';
import '../../utils/profile_validation.dart';
import 'attendance_qr_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final syncService = DataSyncService();
  final searchController = TextEditingController();
  late Future<_EventData> data;
  String? registeringEventId;
  String? cancellingEventId;
  bool registeredExpanded = false;
  bool accountAvailable = false;

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_EventData> loadData() async {
    final events = await syncService.loadEvents();
    final client = SupabaseService.client;
    var registrationStatuses = <String, String>{};
    DateTime? nextEligibleDate;
    DateTime? dateOfBirth;
    String? phone;
    var hasActiveCommitment = false;
    accountAvailable = false;
    if (client != null) {
      try {
        final registrationRepository = EventRegistrationRepository(client);
        registrationStatuses = await registrationRepository
            .getMyRegistrationStatuses()
            .timeout(const Duration(seconds: 10));
        hasActiveCommitment = await registrationRepository
            .hasActiveDonationCommitment()
            .timeout(const Duration(seconds: 10));
        final profile = await ProfileRepository(
          client,
        ).getCurrentProfile().timeout(const Duration(seconds: 10));
        nextEligibleDate = profile.nextEligibleDate;
        dateOfBirth = profile.dateOfBirth;
        phone = profile.phone;
        accountAvailable = true;
      } catch (_) {
        registrationStatuses = {};
      }
    }
    final now = DateTime.now();
    final activeRegistrationEventId = events
        .where(
          (event) =>
              registrationStatuses[event.id] == 'registered' &&
              event.status != 'ended' &&
              event.status != 'cancelled' &&
              event.endsAt.isAfter(now),
        )
        .map((event) => event.id)
        .firstOrNull;
    final visibleEvents = events.where((event) {
      if (event.status == 'upcoming' || event.status == 'in_progress') {
        return event.endsAt.isAfter(now);
      }

      final registrationStatus = registrationStatuses[event.id];
      return event.status == 'ended' &&
          registrationStatus == 'registered' &&
          event.endsAt.add(const Duration(days: 1)).isAfter(now);
    }).toList();
    return _EventData(
      visibleEvents,
      registrationStatuses,
      nextEligibleDate,
      dateOfBirth,
      phone,
      activeRegistrationEventId,
      hasActiveCommitment,
    );
  }

  String dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$minute';
  }

  String timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool matchesSearch(DonationEvent event) {
    final query = searchController.text.trim().toLowerCase();
    return query.isEmpty ||
        event.title.toLowerCase().contains(query) ||
        event.venue.toLowerCase().contains(query) ||
        (event.description?.toLowerCase().contains(query) ?? false);
  }

  bool isEligibleForEvent(DonationEvent event, DateTime? nextEligibleDate) {
    return event.eligibleOnEventDate(nextEligibleDate);
  }

  String? registrationEligibilityMessage(
    DonationEvent event,
    DateTime? nextEligibleDate,
    DateTime? dateOfBirth,
    String? phone,
    String? activeRegistrationEventId,
    bool hasActiveCommitment,
  ) {
    if (hasActiveCommitment && activeRegistrationEventId == null) {
      return 'You already have an active emergency donation response.';
    }
    if (activeRegistrationEventId != null &&
        activeRegistrationEventId != event.id) {
      return 'You are already registered for another active event.';
    }
    if (dateOfBirth == null) {
      return 'Add your date of birth in Profile before registering.';
    }
    if (!ProfileValidation.isAtLeast18(dateOfBirth)) {
      return 'You must be at least 18 years old to register.';
    }
    if (ProfileValidation.phone(phone) != null) {
      return 'Add a valid Malaysian phone number in Profile before registering.';
    }
    if (!isEligibleForEvent(event, nextEligibleDate) &&
        nextEligibleDate != null) {
      return 'You can donate again from ${shortDate(nextEligibleDate)}.';
    }
    return null;
  }

  String shortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> showEventDetails(
    DonationEvent event, {
    required String? registrationStatus,
    required DateTime? nextEligibleDate,
    required DateTime? dateOfBirth,
    required String? phone,
    required String? activeRegistrationEventId,
    required bool hasActiveCommitment,
  }) async {
    final existingReminder = await EventReminderService.instance.reminderFor(
      event.id,
    );
    if (!mounted) return;
    final eligibilityMessage = registrationEligibilityMessage(
      event,
      nextEligibleDate,
      dateOfBirth,
      phone,
      activeRegistrationEventId,
      hasActiveCommitment,
    );
    final eligible = accountAvailable && eligibilityMessage == null;
    final hasRegistration =
        registrationStatus == 'registered' || registrationStatus == 'attended';
    final ended = !event.registrationOpenAt(DateTime.now());
    final qrEventId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (sheetContext) => Scaffold(
          backgroundColor: AppTheme.donorBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.donorHeader,
            foregroundColor: Colors.white,
            titleTextStyle: AppTheme.donorHeaderTitleStyle,
            title: Text(event.title),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bloodtype_outlined, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (event.imagePath case final path?) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        SupabaseService.client!.storage
                            .from('event-images')
                            .getPublicUrl(path),
                        height: 210,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  InstitutionDetailsTile(
                    ownerId: event.createdBy,
                    label: 'Organised by',
                    useDonorColors: true,
                    cachedName: event.organiserName,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Venue'),
                    subtitle: Text(event.venue),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Date and time'),
                    subtitle: Text(eventSchedule(event.startsAt, event.endsAt)),
                  ),
                  if (event.description case final description?) ...[
                    const SizedBox(height: 8),
                    Text(
                      'About this event',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                  if (event.latitude != null && event.longitude != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Event location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              event.latitude!,
                              event.longitude!,
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mobile_asg',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    event.latitude!,
                                    event.longitude!,
                                  ),
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
                                TextSourceAttribution(
                                  'OpenStreetMap contributors',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => openDirections(event),
                        icon: const Icon(Icons.directions_outlined),
                        label: const Text('Open directions'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: AppTheme.donorPrimaryButtonStyle,
                      onPressed:
                          hasRegistration ||
                              registeringEventId != null ||
                              cancellingEventId != null ||
                              !eligible ||
                              ended
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              confirmRegistration(event);
                            },
                      icon: Icon(
                        hasRegistration ? Icons.check : Icons.event_available,
                      ),
                      label: Text(
                        registrationStatus == 'attended'
                            ? 'Attendance verified'
                            : registrationStatus != null
                            ? 'Already registered'
                            : ended
                            ? 'Registration closed'
                            : !accountAvailable
                            ? 'Unavailable'
                            : !eligible
                            ? 'Not eligible'
                            : 'Register',
                      ),
                    ),
                  ),
                  if (registrationStatus == null &&
                      accountAvailable &&
                      eligibilityMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      eligibilityMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (registrationStatus == 'registered') ...[
                    const SizedBox(height: 10),
                    if (event.startsAt.isAfter(DateTime.now())) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            chooseReminder(event);
                          },
                          icon: const Icon(Icons.alarm_add_outlined),
                          label: Text(
                            existingReminder == null
                                ? 'Set event reminder'
                                : 'Reminder: ${dateLabel(existingReminder)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: event.startsAt.isAfter(DateTime.now())
                            ? null
                            : () => Navigator.pop(sheetContext, event.id),
                        icon: const Icon(Icons.qr_code),
                        label: Text(
                          event.startsAt.isAfter(DateTime.now())
                              ? 'QR available when event starts'
                              : 'Show attendance QR',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: cancellingEventId == null
                            ? () {
                                Navigator.pop(sheetContext);
                                confirmCancellation(event);
                              }
                            : null,
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('Cancel registration'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (qrEventId != null && mounted) {
      await showAttendanceQr(event);
    }
  }

  Future<void> showAttendanceQr(DonationEvent event) async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again to show your QR.')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DonorAttendanceQrScreen(event: event, donorId: userId),
      ),
    );
  }

  Future<void> openDirections(DonationEvent event) async {
    final latitude = event.latitude;
    final longitude = event.longitude;
    if (latitude == null || longitude == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open map directions.')),
      );
    }
  }

  Future<void> confirmRegistration(DonationEvent event) async {
    if (!accountAvailable) return;
    if (!event.registrationOpenAt(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration is closed for this event.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.donorBackground,
        title: const Text('Confirm registration'),
        content: Text(
          'Register for ${event.title} at ${event.venue} on '
          '${dateLabel(event.startsAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: AppTheme.donorPrimaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );
    if (confirmed == true) await register(event);
  }

  Future<void> register(DonationEvent event) async {
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => registeringEventId = event.id);
    try {
      await EventRegistrationRepository(client).register(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event registration completed.')),
      );
      setState(() {
        data = loadData();
      });
      await chooseReminder(event, afterRegistration: true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => registeringEventId = null);
    }
  }

  Future<void> confirmCancellation(DonationEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.donorBackground,
        title: const Text('Cancel registration?'),
        content: Text(
          'Cancel your registration for ${event.title}? You can register for another available event afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep registration'),
          ),
          FilledButton(
            style: AppTheme.donorPrimaryButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await cancelRegistration(event);
  }

  Future<void> cancelRegistration(DonationEvent event) async {
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => cancellingEventId = event.id);
    try {
      await EventRegistrationRepository(client).cancel(event.id);
      try {
        await EventReminderService.instance.cancel(event.id);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event registration cancelled.')),
      );
      setState(() => data = loadData());
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => cancellingEventId = null);
    }
  }

  Future<void> chooseReminder(
    DonationEvent event, {
    bool afterRegistration = false,
  }) async {
    if (!event.startsAt.isAfter(DateTime.now())) return;
    if (!mounted) return;
    final existing = await EventReminderService.instance.reminderFor(event.id);
    if (!mounted) return;
    final choice = await showModalBottomSheet<_ReminderChoice>(
      context: context,
      backgroundColor: AppTheme.donorBackground,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  afterRegistration
                      ? 'Add an event reminder?'
                      : 'Event reminder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text('${event.title} starts ${dateLabel(event.startsAt)}.'),
                const SizedBox(height: 6),
                Text(
                  EventReminderService.emailEnabled
                      ? 'Send to your login email and the app inbox. On mobile, also schedule a phone notification when permission is allowed.'
                      : 'Phone notifications are available. Email reminders require server setup.',
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.today_outlined),
                  title: const Text('1 day before'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ReminderChoice.oneDayBefore),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('2 hours before'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _ReminderChoice.twoHoursBefore,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('Choose custom date and time'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ReminderChoice.custom),
                ),
                if (existing != null)
                  ListTile(
                    leading: const Icon(Icons.alarm_off_outlined),
                    title: const Text('Cancel current reminder'),
                    subtitle: Text(dateLabel(existing)),
                    onTap: () =>
                        Navigator.pop(sheetContext, _ReminderChoice.cancel),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == _ReminderChoice.cancel) {
      try {
        await EventReminderService.instance.cancel(event.id);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event reminder cancelled.')),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to cancel the reminder. Please check your connection and retry.',
            ),
          ),
        );
      }
      return;
    }

    DateTime? reminderAt;
    if (choice == _ReminderChoice.oneDayBefore) {
      reminderAt = event.startsAt.subtract(const Duration(days: 1));
    } else if (choice == _ReminderChoice.twoHoursBefore) {
      reminderAt = event.startsAt.subtract(const Duration(hours: 2));
    } else {
      reminderAt = await pickCustomReminder(event);
    }
    if (reminderAt == null || !mounted) return;

    try {
      final result = await EventReminderService.instance.schedule(
        event: event,
        reminderAt: reminderAt,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$result Time: ${dateLabel(reminderAt)}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<DateTime?> pickCustomReminder(DonationEvent event) async {
    final now = DateTime.now();
    final eventDay = DateTime(
      event.startsAt.year,
      event.startsAt.month,
      event.startsAt.day,
    );
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.isAfter(eventDay) ? eventDay : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: eventDay,
      helpText: 'Choose reminder date',
    );
    if (selectedDate == null || !mounted) return null;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        event.startsAt.subtract(const Duration(hours: 2)),
      ),
      helpText: 'Choose reminder time',
    );
    if (selectedTime == null) return null;
    final value = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!value.isAfter(DateTime.now()) || !value.isBefore(event.startsAt)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a future time before the event starts.'),
          ),
        );
      }
      return null;
    }
    return value;
  }

  Widget eventCard(
    DonationEvent event, {
    required String? registrationStatus,
    required DateTime? nextEligibleDate,
    required DateTime? dateOfBirth,
    required String? phone,
    required String? activeRegistrationEventId,
    required bool hasActiveCommitment,
  }) {
    final registered =
        registrationStatus == 'registered' || registrationStatus == 'attended';
    final eligibilityMessage = registrationEligibilityMessage(
      event,
      nextEligibleDate,
      dateOfBirth,
      phone,
      activeRegistrationEventId,
      hasActiveCommitment,
    );
    final eligible = accountAvailable && eligibilityMessage == null;
    final ended = !event.registrationOpenAt(DateTime.now());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bloodtype_outlined, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(event.venue)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(eventSchedule(event.startsAt, event.endsAt)),
                ),
              ],
            ),
            InstitutionDetailsTile(
              ownerId: event.createdBy,
              label: 'Organised by',
              useDonorColors: true,
              cachedName: event.organiserName,
            ),
            if (registered && event.startsAt.isAfter(DateTime.now()))
              FutureBuilder<DateTime?>(
                future: EventReminderService.instance.reminderFor(event.id),
                builder: (context, snapshot) {
                  final reminder = snapshot.data;
                  if (reminder == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () => chooseReminder(event),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_on_outlined, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reminder: ${dateLabel(reminder)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(Icons.edit_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (event.description case final description?) ...[
              const SizedBox(height: 8),
              Text(description),
            ],
            if (!registered &&
                accountAvailable &&
                eligibilityMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      eligibilityMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => showEventDetails(
                    event,
                    nextEligibleDate: nextEligibleDate,
                    dateOfBirth: dateOfBirth,
                    phone: phone,
                    activeRegistrationEventId: activeRegistrationEventId,
                    hasActiveCommitment: hasActiveCommitment,
                    registrationStatus: registrationStatus,
                  ),
                  child: const Text('View details'),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: AppTheme.donorPrimaryButtonStyle,
                  onPressed:
                      registered ||
                          !eligible ||
                          ended ||
                          registeringEventId != null
                      ? null
                      : () => confirmRegistration(event),
                  icon: registeringEventId == event.id
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(registered ? Icons.check : Icons.event_available),
                  label: Text(
                    registrationStatus == 'attended'
                        ? 'Attended'
                        : registered
                        ? 'Registered'
                        : ended
                        ? 'Registration closed'
                        : !accountAvailable
                        ? 'Unavailable'
                        : !eligible
                        ? 'Not eligible'
                        : 'Register',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Donation Events'),
      ),
      body: FutureBuilder<_EventData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load events: ${snapshot.error}'),
            );
          }
          final value =
              snapshot.data ??
              const _EventData([], {}, null, null, null, null, false);
          final matching = value.events.where(matchesSearch).toList();
          final registered = matching
              .where(
                (event) =>
                    value.registrationStatuses[event.id] == 'registered' ||
                    value.registrationStatuses[event.id] == 'attended',
              )
              .toList();
          final available = matching
              .where(
                (event) =>
                    !value.registrationStatuses.containsKey(event.id) ||
                    value.registrationStatuses[event.id] == 'cancelled',
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() {
              data = loadData();
            }),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search event or venue',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: AppTheme.donorBackground.withValues(alpha: .28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppTheme.donorMutedOutline),
                  ),
                  child: ExpansionTile(
                    enabled: accountAvailable,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    initiallyExpanded: registeredExpanded,
                    onExpansionChanged: (expanded) =>
                        setState(() => registeredExpanded = expanded),
                    leading: const Icon(Icons.how_to_reg),
                    title: const Text('My registered events'),
                    subtitle: Text(
                      '${registered.length} event${registered.length == 1 ? '' : 's'}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: registered.isEmpty
                        ? const [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No registered events.'),
                            ),
                          ]
                        : [
                            for (final event in registered) ...[
                              eventCard(
                                event,
                                registrationStatus:
                                    value.registrationStatuses[event.id],
                                nextEligibleDate: value.nextEligibleDate,
                                dateOfBirth: value.dateOfBirth,
                                phone: value.phone,
                                activeRegistrationEventId:
                                    value.activeRegistrationEventId,
                                hasActiveCommitment: value.hasActiveCommitment,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!accountAvailable)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Read-only view: account eligibility could not be checked. Connect to the internet and reopen Events to register or view your registrations. Cached events may be out of date.',
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      'Available events',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text('${available.length}'),
                  ],
                ),
                const SizedBox(height: 12),
                if (available.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        value.events.isEmpty
                            ? 'No upcoming donation events.'
                            : 'No available events match your search.',
                      ),
                    ),
                  )
                else
                  for (final event in available) ...[
                    eventCard(
                      event,
                      registrationStatus: null,
                      nextEligibleDate: value.nextEligibleDate,
                      dateOfBirth: value.dateOfBirth,
                      phone: value.phone,
                      activeRegistrationEventId:
                          value.activeRegistrationEventId,
                      hasActiveCommitment: value.hasActiveCommitment,
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventData {
  const _EventData(
    this.events,
    this.registrationStatuses,
    this.nextEligibleDate,
    this.dateOfBirth,
    this.phone,
    this.activeRegistrationEventId,
    this.hasActiveCommitment,
  );

  final List<DonationEvent> events;
  final Map<String, String> registrationStatuses;
  final DateTime? nextEligibleDate;
  final DateTime? dateOfBirth;
  final String? phone;
  final String? activeRegistrationEventId;
  final bool hasActiveCommitment;
}

enum _ReminderChoice { oneDayBefore, twoHoursBefore, custom, cancel }
