import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final attendanceApiProvider = Provider<AttendanceApi>((ref) {
  return AttendanceApi(ref.watch(tenantApiClientProvider));
});

class AttendanceApi {
  const AttendanceApi(this._client);

  final TenantApiClient _client;

  Future<List<AttendanceEntry>> listAttendance({
    required String siteId,
    required DateTime date,
  }) async {
    final data = await _client.get(
      '/attendance',
      query: {'siteId': siteId, 'date': _dateQuery(date)},
    );
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid attendance data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .map((item) => AttendanceEntry.fromJson(_map(item, 'attendance')))
        .toList(growable: false);
  }

  Future<AttendanceEntry> createAttendance({
    required String staffId,
    required String siteId,
    required DateTime date,
    required String status,
  }) async {
    final data = await _client.post(
      '/attendance',
      body: {
        'staffId': staffId,
        'siteId': siteId,
        'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
        'status': status,
        'shiftType': 'REGULAR',
      },
    );
    return AttendanceEntry.fromJson(_map(data, 'attendance'));
  }
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.id,
    required this.staffId,
    required this.siteId,
    required this.date,
    required this.status,
    required this.shiftType,
    required this.staff,
    required this.site,
    this.markedBy,
  });

  final String id;
  final String staffId;
  final String siteId;
  final DateTime date;
  final String status;
  final String shiftType;
  final AttendanceStaff staff;
  final AttendanceSite site;
  final AttendanceMarker? markedBy;

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceEntry(
      id: _requiredString(json, 'id'),
      staffId: _requiredString(json, 'staffId'),
      siteId: _requiredString(json, 'siteId'),
      date: _requiredDate(json, 'date'),
      status: _requiredString(json, 'status').toUpperCase(),
      shiftType: _requiredString(json, 'shiftType').toUpperCase(),
      staff: AttendanceStaff.fromJson(_map(json['staff'], 'staff')),
      site: AttendanceSite.fromJson(_map(json['site'], 'site')),
      markedBy: json['markedBy'] == null
          ? null
          : AttendanceMarker.fromJson(_map(json['markedBy'], 'marker')),
    );
  }
}

class AttendanceStaff {
  const AttendanceStaff({
    required this.id,
    required this.publicId,
    required this.workerType,
    required this.status,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String publicId;
  final String? firstName;
  final String? lastName;
  final String workerType;
  final String status;

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? publicId : name;
  }

  factory AttendanceStaff.fromJson(Map<String, dynamic> json) {
    return AttendanceStaff(
      id: _requiredString(json, 'id'),
      publicId: _requiredString(json, 'publicId'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
      workerType: _requiredString(json, 'workerType'),
      status: _requiredString(json, 'status').toUpperCase(),
    );
  }
}

class AttendanceSite {
  const AttendanceSite({
    required this.id,
    required this.publicId,
    required this.name,
  });

  final String id;
  final String publicId;
  final String name;

  factory AttendanceSite.fromJson(Map<String, dynamic> json) {
    return AttendanceSite(
      id: _requiredString(json, 'id'),
      publicId: _requiredString(json, 'publicId'),
      name: _requiredString(json, 'name'),
    );
  }
}

class AttendanceMarker {
  const AttendanceMarker({required this.id, this.firstName, this.lastName});

  final String id;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'Name unavailable' : name;
  }

  factory AttendanceMarker.fromJson(Map<String, dynamic> json) {
    return AttendanceMarker(
      id: _requiredString(json, 'id'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
    );
  }
}

String _dateQuery(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Map<String, dynamic> _map(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw TenantApiException(
    'The server response is missing $field.',
    code: 'INVALID_RESPONSE',
  );
}

String? _optionalString(dynamic value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

DateTime _requiredDate(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}
