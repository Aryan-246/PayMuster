import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final payrollApiProvider = Provider<PayrollApi>((ref) {
  return PayrollApi(ref.watch(tenantApiClientProvider));
});

final payRunsProvider = FutureProvider<List<PayRunSummary>>((ref) {
  return ref.watch(payrollApiProvider).listPayRuns();
});

class PayrollApi {
  const PayrollApi(this._client);

  final TenantApiClient _client;

  Future<List<PayRunSummary>> listPayRuns({String? payCycleId}) async {
    final data = await _client.get(
      '/payroll',
      query: {'payCycleId': payCycleId},
    );
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid payroll data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .map((item) => PayRunSummary.fromJson(_map(item, 'pay run')))
        .toList(growable: false);
  }
}

class PayRunSummary {
  const PayRunSummary({
    required this.id,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.payCycle,
    required this.items,
    this.publicId,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String? publicId;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final PayrollApprover? approvedBy;
  final PayrollCycle payCycle;
  final List<PayRunItem> items;

  int get staffCount => items.length;

  factory PayRunSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['payRunItems'];
    if (rawItems is! List) {
      throw const TenantApiException(
        'The server returned invalid payroll item data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return PayRunSummary(
      id: _requiredString(json, 'id'),
      publicId: _optionalString(json['publicId']),
      totalAmount: _requiredMoney(json, 'totalAmount'),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      approvedAt: _optionalDate(json['approvedAt'], 'approvedAt'),
      approvedBy: _optionalApprover(json['approvedBy']),
      payCycle: PayrollCycle.fromJson(_map(json['payCycle'], 'pay cycle')),
      items: rawItems
          .map((item) => PayRunItem.fromJson(_map(item, 'payroll item')))
          .toList(growable: false),
    );
  }
}

class PayrollCycle {
  const PayrollCycle({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  factory PayrollCycle.fromJson(Map<String, dynamic> json) {
    return PayrollCycle(
      id: _requiredString(json, 'id'),
      startDate: _requiredDate(json, 'startDate'),
      endDate: _requiredDate(json, 'endDate'),
      status: _requiredString(json, 'status').toUpperCase(),
    );
  }
}

class PayrollApprover {
  const PayrollApprover({required this.id, this.firstName, this.lastName});

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

  factory PayrollApprover.fromJson(Map<String, dynamic> json) {
    return PayrollApprover(
      id: _requiredString(json, 'id'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
    );
  }
}

class PayRunItem {
  const PayRunItem({
    required this.id,
    required this.staffId,
    required this.grossPay,
    required this.deductions,
    required this.additions,
    required this.arrears,
    required this.netPay,
    required this.staff,
  });

  final String id;
  final String staffId;
  final double grossPay;
  final Map<String, double> deductions;
  final Map<String, double> additions;
  final Map<String, double> arrears;
  final double netPay;
  final PayrollStaff staff;

  double get deductionTotal => _sum(deductions);
  double get additionTotal => _sum(additions);
  double get arrearsTotal => _sum(arrears);

  factory PayRunItem.fromJson(Map<String, dynamic> json) {
    return PayRunItem(
      id: _requiredString(json, 'id'),
      staffId: _requiredString(json, 'staffId'),
      grossPay: _requiredMoney(json, 'grossPay'),
      deductions: _moneyMap(json['deductions'], 'deductions'),
      additions: _moneyMap(json['additions'], 'additions'),
      arrears: _moneyMap(json['arrears'], 'arrears'),
      netPay: _requiredMoney(json, 'netPay'),
      staff: PayrollStaff.fromJson(_map(json['staff'], 'payroll staff')),
    );
  }
}

class PayrollStaff {
  const PayrollStaff({
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

  factory PayrollStaff.fromJson(Map<String, dynamic> json) {
    return PayrollStaff(
      id: _requiredString(json, 'id'),
      publicId: _requiredString(json, 'publicId'),
      firstName: _optionalString(json['firstName']),
      lastName: _optionalString(json['lastName']),
      workerType: _requiredString(json, 'workerType'),
      status: _requiredString(json, 'status').toUpperCase(),
    );
  }
}

double _sum(Map<String, double> values) {
  return values.values.fold(0, (total, amount) => total + amount);
}

PayrollApprover? _optionalApprover(dynamic value) {
  if (value == null) return null;
  return PayrollApprover.fromJson(_map(value, 'payroll approver'));
}

Map<String, double> _moneyMap(dynamic value, String field) {
  if (value is! Map<String, dynamic>) {
    throw TenantApiException(
      'The server response contains invalid $field data.',
      code: 'INVALID_RESPONSE',
    );
  }
  return value.map((key, amount) {
    final parsed = _moneyValue(amount);
    if (key.trim().isEmpty || parsed == null || parsed < 0) {
      throw TenantApiException(
        'The server response contains invalid $field data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return MapEntry(key, parsed);
  });
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

double _requiredMoney(Map<String, dynamic> json, String field) {
  final value = _moneyValue(json[field]);
  if (value != null && value.isFinite && value >= 0) return value;
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

double? _moneyValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime _requiredDate(Map<String, dynamic> json, String field) {
  final value = _optionalDate(json[field], field);
  if (value != null) return value;
  throw TenantApiException(
    'The server response is missing $field.',
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
