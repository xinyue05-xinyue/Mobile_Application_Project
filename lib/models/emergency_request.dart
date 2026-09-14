class EmergencyRequest {
  const EmergencyRequest({
    required this.id,
    required this.hospitalId,
    required this.bloodType,
    required this.urgency,
    required this.deadline,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String hospitalId;
  final String bloodType;
  final String urgency;
  final DateTime deadline;
  final String status;
  final DateTime createdAt;

  factory EmergencyRequest.fromMap(Map<String, Object?> map) =>
      EmergencyRequest(
        id: map['id']! as String,
        hospitalId: map['hospital_id']! as String,
        bloodType: map['blood_type']! as String,
        urgency: map['urgency']! as String,
        deadline: DateTime.parse(map['deadline']! as String).toLocal(),
        status: map['status']! as String,
        createdAt: DateTime.parse(map['created_at']! as String).toLocal(),
      );
}
