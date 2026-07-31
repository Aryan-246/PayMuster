class AttendanceRecord {
  final String id;
  final String workerId;
  final String siteId;
  final DateTime date;
  final String status; // Present, Absent, Half Day, On Leave

  const AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.siteId,
    required this.date,
    required this.status,
  });

  AttendanceRecord copyWith({
    String? id,
    String? workerId,
    String? siteId,
    DateTime? date,
    String? status,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      siteId: siteId ?? this.siteId,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }
}
