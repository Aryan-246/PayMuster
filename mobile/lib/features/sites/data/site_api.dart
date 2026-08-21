import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final siteApiProvider = Provider<SiteApi>((ref) {
  return SiteApi(ref.watch(tenantApiClientProvider));
});

final sitesProvider = FutureProvider<List<SiteSummary>>((ref) {
  return ref.watch(siteApiProvider).listSites();
});

class SiteApi {
  const SiteApi(this._client);

  final TenantApiClient _client;

  Future<List<SiteSummary>> listSites({String? status}) async {
    final data = await _client.get('/sites', query: {'status': status});
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid site data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .map((item) => SiteSummary.fromJson(_map(item, 'site')))
        .toList(growable: false);
  }
}

class SiteSummary {
  const SiteSummary({
    required this.id,
    required this.publicId,
    required this.name,
    required this.status,
    required this.workerCount,
    required this.workers,
    required this.approvedExpenseTotal,
    this.address,
    this.startDate,
    this.expectedEndDate,
    this.manager,
    this.supervisor,
  });

  final String id;
  final String publicId;
  final String name;
  final String? address;
  final String status;
  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final int workerCount;
  final SitePerson? manager;
  final SitePerson? supervisor;
  final List<SiteWorker> workers;
  final double approvedExpenseTotal;

  bool get isActive => status == 'ACTIVE';

  factory SiteSummary.fromJson(Map<String, dynamic> json) {
    final rawWorkers = json['workers'];
    if (rawWorkers is! List) {
      throw const TenantApiException(
        'The server returned invalid site worker data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return SiteSummary(
      id: _requiredString(json, 'id'),
      publicId: _requiredString(json, 'publicId'),
      name: _requiredString(json, 'name'),
      address: _optionalString(json['address']),
      status: _requiredString(json, 'status').toUpperCase(),
      startDate: _optionalDate(json['startDate'], 'startDate'),
      expectedEndDate: _optionalDate(
        json['expectedEndDate'],
        'expectedEndDate',
      ),
      workerCount: _requiredInt(json, 'workerCount'),
      manager: _optionalPerson(json['manager'], 'manager'),
      supervisor: _optionalPerson(json['supervisor'], 'supervisor'),
      workers: rawWorkers
          .map((item) => SiteWorker.fromJson(_map(item, 'worker')))
          .toList(growable: false),
      approvedExpenseTotal: _requiredDouble(json, 'approvedExpenseTotal'),
    );
  }
}

class SitePerson {
  const SitePerson({required this.id, this.firstName, this.lastName});

  final String id;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final name = [firstName, lastName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? 'Name unavailable' : name;
  }

  factory SitePerson.fromJson(Map<String, dynamic> json) {
    return SitePerson(
      id: _requiredString(json, 'id'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
    );
  }
}

class SiteWorker {
  const SiteWorker({
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
    final name = [firstName, lastName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? publicId : name;
  }

  factory SiteWorker.fromJson(Map<String, dynamic> json) {
    return SiteWorker(
      id: _requiredString(json, 'id'),
      publicId: _requiredString(json, 'publicId'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
      workerType: _requiredString(json, 'workerType'),
      status: _requiredString(json, 'status').toUpperCase(),
    );
  }
}

SitePerson? _optionalPerson(dynamic value, String field) {
  if (value == null) return null;
  return SitePerson.fromJson(_map(value, field));
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
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The server response is missing $field.',
    code: 'INVALID_RESPONSE',
  );
}

String? _optionalString(dynamic value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

DateTime? _optionalDate(dynamic value, String field) {
  if (value == null) return null;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}
