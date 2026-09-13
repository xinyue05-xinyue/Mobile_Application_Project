class AttendanceQr {
  static final _pattern = RegExp(
    r'^mydarah:event:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}):donor:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
  );

  static String donorForEvent(String? value, String eventId) {
    final payload = parse(value);
    if (payload.eventId != eventId.toLowerCase()) {
      throw const FormatException(
        'This QR belongs to a different event. Ask the donor to open the QR for this event.',
      );
    }
    return payload.donorId;
  }

  static AttendanceQrPayload parse(String? value) {
    final match = value == null ? null : _pattern.firstMatch(value.trim());
    if (match == null) {
      throw const FormatException('This is not a valid MyDarah donor QR.');
    }
    return AttendanceQrPayload(
      eventId: match.group(1)!.toLowerCase(),
      donorId: match.group(2)!.toLowerCase(),
    );
  }
}

class AttendanceQrPayload {
  const AttendanceQrPayload({required this.eventId, required this.donorId});

  final String eventId;
  final String donorId;
}
