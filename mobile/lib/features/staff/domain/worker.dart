/// Mirrors GET /api/v1/staff and GET /api/v1/staff/:id (staff-directory
/// service). Every field comes from the server — the roster select
/// deliberately excludes financial PII, so no wage/advance fields exist here.
class Worker {
  final String id;
  final String? publicId;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String workerType;
  final String status;
  final DateTime? joinDate;
  final int documentCount;
  final int siteAssignmentCount;

  const Worker({
    required this.id,
    required this.workerType,
    required this.status,
    required this.documentCount,
    required this.siteAssignmentCount,
    this.publicId,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.joinDate,
  });

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? (publicId ?? 'Staff member') : name;
  }

  String get initials {
    final first = firstName?.trim().isNotEmpty == true ? firstName!.trim()[0] : '';
    final last = lastName?.trim().isNotEmpty == true ? lastName!.trim()[0] : '';
    if ('$first$last'.isEmpty) return '?';
    return '$first$last'.toUpperCase();
  }

  factory Worker.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return Worker(
      id: _requiredString(json, 'id'),
      publicId: _optionalString(json['publicId']),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
      phone: _optionalString(json['phone']),
      email: _optionalString(json['email']),
      workerType: _requiredString(json, 'workerType'),
      status: _requiredString(json, 'status').toUpperCase(),
      joinDate: _optionalDate(json['joinDate']),
      documentCount: count is Map<String, dynamic> ? (count['documents'] as int? ?? 0) : 0,
      siteAssignmentCount: count is Map<String, dynamic> ? (count['siteAssignments'] as int? ?? 0) : 0,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('The server response is missing $field.');
}

String? _optionalString(dynamic value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

DateTime? _optionalDate(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
