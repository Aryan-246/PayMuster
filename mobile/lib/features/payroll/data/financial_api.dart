import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

/// Payment row from GET /api/v1/financial/payments (view_payroll-gated).
/// Money values stay server-authoritative; the client only renders them.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.mode,
    required this.status,
    required this.createdAt,
    this.referenceId,
    this.approvedAt,
    this.failureReason,
    required this.staffName,
    required this.staffPublicId,
  });

  final String id;
  final String amount;
  final String mode;
  final String status;
  final DateTime createdAt;
  final String? referenceId;
  final DateTime? approvedAt;
  final String? failureReason;
  final String staffName;
  final String staffPublicId;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'];
    final staffMap = staff is Map<String, dynamic> ? staff : <String, dynamic>{};
    return PaymentRecord(
      id: _requiredString(json, 'id'),
      amount: _decimalString(json['amount']),
      mode: json['mode'] as String? ?? 'CASH',
      status: json['status'] as String? ?? 'DRAFT',
      createdAt: _optionalDate(json['createdAt']) ?? DateTime(1970),
      referenceId: _optionalString(json['referenceId']),
      approvedAt: _optionalDate(json['approvedAt']),
      failureReason: _optionalString(json['failureReason']),
      staffName: staffMap['firstName'] is String && staffMap['lastName'] is String
          ? '${staffMap['firstName']} ${staffMap['lastName']}'
          : 'Unknown staff',
      staffPublicId: staffMap['publicId'] is String
          ? staffMap['publicId'] as String
          : '',
    );
  }
}

/// Expense row from GET /api/v1/financial/expenses (view_payroll-gated).
class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.amount,
    required this.category,
    required this.status,
    required this.date,
    required this.createdAt,
    this.paymentMethod,
    this.notes,
    required this.siteName,
    required this.paidByName,
  });

  final String id;
  final String amount;
  final String category;
  final String status;
  final DateTime date;
  final DateTime createdAt;
  final String? paymentMethod;
  final String? notes;
  final String siteName;
  final String paidByName;

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    final site = json['site'];
    final paidBy = json['paidBy'];
    final siteMap = site is Map<String, dynamic> ? site : <String, dynamic>{};
    final paidByMap =
        paidBy is Map<String, dynamic> ? paidBy : <String, dynamic>{};
    return ExpenseRecord(
      id: _requiredString(json, 'id'),
      amount: _decimalString(json['amount']),
      category: json['category'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      date: _optionalDate(json['date']) ?? DateTime(1970),
      createdAt: _optionalDate(json['createdAt']) ?? DateTime(1970),
      paymentMethod: _optionalString(json['paymentMethod']),
      notes: _optionalString(json['notes']),
      siteName: siteMap['name'] is String ? siteMap['name'] as String : '',
      paidByName:
          paidByMap['firstName'] is String && paidByMap['lastName'] is String
          ? '${paidByMap['firstName']} ${paidByMap['lastName']}'
          : '',
    );
  }
}

class FinancialPage<T> {
  const FinancialPage({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Owner-facing financial lists. The backend enforces view_payroll + org
/// scope; this client only transports queries and renders results.
class FinancialApi {
  const FinancialApi(this._client);

  final TenantApiClient _client;

  Future<FinancialPage<PaymentRecord>> listPayments({
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    final envelope = await _client.getWithMeta(
      '/financial/payments',
      query: {'page': '$page', 'limit': '$limit', 'status': status},
    );
    final rows = envelope.data;
    if (rows is! List) {
      throw const TenantApiException(
        'The server returned invalid payment data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return FinancialPage(
      items: rows
          .map((row) => PaymentRecord.fromJson(_map(row, 'payment')))
          .toList(growable: false),
      total: envelope.intMeta('total') ?? 0,
      page: envelope.intMeta('page') ?? page,
      totalPages: envelope.intMeta('totalPages') ?? 0,
    );
  }

  Future<FinancialPage<ExpenseRecord>> listExpenses({
    String? status,
    int page = 1,
    int limit = 25,
  }) async {
    final envelope = await _client.getWithMeta(
      '/financial/expenses',
      query: {'page': '$page', 'limit': '$limit', 'status': status},
    );
    final rows = envelope.data;
    if (rows is! List) {
      throw const TenantApiException(
        'The server returned invalid expense data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return FinancialPage(
      items: rows
          .map((row) => ExpenseRecord.fromJson(_map(row, 'expense')))
          .toList(growable: false),
      total: envelope.intMeta('total') ?? 0,
      page: envelope.intMeta('page') ?? page,
      totalPages: envelope.intMeta('totalPages') ?? 0,
    );
  }
}

final financialApiProvider = Provider<FinancialApi>((ref) {
  return FinancialApi(ref.watch(tenantApiClientProvider));
});

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

String? _optionalString(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _optionalDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _decimalString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  return '0';
}
