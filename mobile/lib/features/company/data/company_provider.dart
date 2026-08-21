import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';

final companyProvider = Provider<CompanyApi>((ref) {
  final api = CompanyApi(ref);
  ref.onDispose(api.close);
  return api;
});

class CompanyApiException implements Exception {
  const CompanyApiException(
    this.message, {
    required this.code,
    this.statusCode,
  });

  final String message;
  final String code;
  final int? statusCode;

  @override
  String toString() => message;
}

class OwnerRequest {
  const OwnerRequest({
    required this.id,
    required this.companyName,
    required this.status,
    this.publicId,
    this.companyAddress,
    this.gstin,
    this.businessRegistrationUrl,
    this.identityProofUrl,
    this.rejectionReason,
  });

  final String id;
  final String? publicId;
  final String companyName;
  final String? companyAddress;
  final String? gstin;
  final String? businessRegistrationUrl;
  final String? identityProofUrl;
  final String status;
  final String? rejectionReason;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory OwnerRequest.fromJson(Map<String, dynamic> json) {
    return OwnerRequest(
      id: _requiredString(json, 'id'),
      publicId: json['publicId'] as String?,
      companyName: _requiredString(json, 'companyName'),
      companyAddress: json['companyAddress'] as String?,
      gstin: json['gstin'] as String?,
      businessRegistrationUrl: json['businessRegistrationUrl'] as String?,
      identityProofUrl: json['identityProofUrl'] as String?,
      status: _requiredString(json, 'status').toUpperCase(),
      rejectionReason: json['deleteReason'] as String?,
    );
  }
}

class CompanyFinancialSummary {
  const CompanyFinancialSummary({
    required this.includedExpenseStatuses,
    required this.siteLinkedExpenseTotal,
    required this.companyLevelExpenseTotal,
    required this.recordedPayRunCount,
    required this.recordedPayRunTotal,
  });

  final List<String> includedExpenseStatuses;
  final String siteLinkedExpenseTotal;
  final String companyLevelExpenseTotal;
  final int recordedPayRunCount;
  final String recordedPayRunTotal;

  factory CompanyFinancialSummary.fromJson(Map<String, dynamic>? json) {
    final expenses = _mapValueOrEmpty(json?['expenses']);
    final payRuns = _mapValueOrEmpty(json?['payRuns']);
    final statuses = expenses['includedStatuses'];

    return CompanyFinancialSummary(
      includedExpenseStatuses: statuses is List
          ? statuses.whereType<String>().toList(growable: false)
          : const ['APPROVED', 'REIMBURSED'],
      siteLinkedExpenseTotal: _decimalString(
        expenses['siteLinkedTotal'],
        field: 'financialSummary.expenses.siteLinkedTotal',
      ),
      companyLevelExpenseTotal: _decimalString(
        expenses['companyLevelTotal'],
        field: 'financialSummary.expenses.companyLevelTotal',
      ),
      recordedPayRunCount: _integerOrZero(
        payRuns['recordedCount'],
        field: 'financialSummary.payRuns.recordedCount',
      ),
      recordedPayRunTotal: _decimalString(
        payRuns['recordedTotal'],
        field: 'financialSummary.payRuns.recordedTotal',
      ),
    );
  }
}

class CompanyOverview {
  const CompanyOverview({
    required this.id,
    required this.name,
    required this.userCount,
    required this.siteCount,
    required this.staffCount,
    this.publicId,
    this.joinCode,
    this.referenceCode,
    this.currency = 'INR',
    this.financialSummary = const CompanyFinancialSummary(
      includedExpenseStatuses: ['APPROVED', 'REIMBURSED'],
      siteLinkedExpenseTotal: '0',
      companyLevelExpenseTotal: '0',
      recordedPayRunCount: 0,
      recordedPayRunTotal: '0',
    ),
  });

  final String id;
  final String? publicId;
  final String name;
  final String? joinCode;
  final String? referenceCode;
  final String currency;
  final int userCount;
  final int siteCount;
  final int staffCount;
  final CompanyFinancialSummary financialSummary;

  factory CompanyOverview.fromJson(Map<String, dynamic> json) {
    final counts = _mapValue(json['_count'], field: '_count');
    final settings = _mapValueOrEmpty(json['settings']);
    return CompanyOverview(
      id: _requiredString(json, 'id'),
      publicId: json['publicId'] as String?,
      name: _requiredString(json, 'name'),
      joinCode: json['joinCode'] as String?,
      referenceCode: json['referenceCode'] as String?,
      currency: _optionalString(settings['currency']) ?? 'INR',
      userCount: _integerValue(counts['users'], field: '_count.users'),
      siteCount: _integerValue(counts['sites'], field: '_count.sites'),
      staffCount: _integerValue(counts['staff'], field: '_count.staff'),
      financialSummary: CompanyFinancialSummary.fromJson(
        _mapValueOrNull(json['financialSummary']),
      ),
    );
  }
}

class CompanyApi {
  CompanyApi(this.ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;

  void close() => _client.close();

  Future<Map<String, dynamic>> lookupCompany(String code) async {
    final uri = Uri.parse(
      '${Env.apiBaseUrl}/api/v1/company/lookup',
    ).replace(queryParameters: {'code': code});
    final response = await _sendPublic('GET', uri);
    return _mapValue(response['data'], field: 'data');
  }

  Future<void> joinCompany(String companyId, {String? notes}) async {
    await _authenticatedData(
      'POST',
      '/company/join',
      tenantId: companyId,
      body: {'notes': ?_trimmedOrNull(notes)},
    );
  }

  Future<CompanyOverview> getOverview(String companyId) async {
    final data = await _authenticatedData(
      'GET',
      '/company/',
      tenantId: companyId,
    );
    return CompanyOverview.fromJson(_mapValue(data, field: 'data'));
  }

  Future<Map<String, dynamic>> getJoinRequests(String companyId) async {
    final data = await _authenticatedData(
      'GET',
      '/company/join',
      tenantId: companyId,
    );
    return _mapValue(data, field: 'data');
  }

  Future<Map<String, dynamic>> requestPromotion(
    String requestedRole, {
    required String companyId,
    String? reason,
  }) async {
    final data = await _authenticatedData(
      'POST',
      '/company/promotion',
      tenantId: companyId,
      body: {'requestedRole': requestedRole, 'reason': ?_trimmedOrNull(reason)},
    );
    return _mapValue(data, field: 'data');
  }

  Future<OwnerRequest?> getMyOwnerRequest() async {
    final data = await _authenticatedData('GET', '/company/owner-request/my');
    if (data == null) return null;
    return OwnerRequest.fromJson(_mapValue(data, field: 'data'));
  }

  Future<OwnerRequest> requestOwnership(
    String companyName, {
    String? companyAddress,
    String? gstin,
    String? businessRegistrationUrl,
    String? identityProofUrl,
  }) async {
    final data = await _authenticatedData(
      'POST',
      '/company/owner-request',
      body: {
        'companyName': companyName.trim(),
        'companyAddress': ?_trimmedOrNull(companyAddress),
        'gstin': ?_trimmedOrNull(gstin),
        'businessRegistrationUrl': ?_trimmedOrNull(businessRegistrationUrl),
        'identityProofUrl': ?_trimmedOrNull(identityProofUrl),
      },
    );
    return OwnerRequest.fromJson(_mapValue(data, field: 'data'));
  }

  Future<Map<String, dynamic>> userAction(
    String userId,
    String action, {
    String? role,
  }) async {
    final data = await _authenticatedData(
      'POST',
      '/admin/users/$userId/action',
      body: {'action': action, 'role': ?role},
    );
    return _mapValue(data, field: 'data');
  }

  Future<dynamic> _authenticatedData(
    String method,
    String path, {
    String? tenantId,
    Map<String, dynamic>? body,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const CompanyApiException(
        'Your session has expired. Please sign in again.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
      );
    }

    final response = await _send(
      method,
      Uri.parse('${Env.apiBaseUrl}/api/v1$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-company-id': ?tenantId,
      },
      body: body,
    );

    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _authenticatedData(
        method,
        path,
        tenantId: tenantId,
        body: body,
        canRetry: false,
      );
    }

    final decoded = _decodeResponse(response);
    return decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  Future<Map<String, dynamic>> _sendPublic(String method, Uri uri) async {
    final response = await _send(
      method,
      uri,
      headers: const {'Content-Type': 'application/json'},
    );
    return _decodeResponse(response);
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      return switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => throw CompanyApiException(
          'Unsupported company request method: $method',
          code: 'UNSUPPORTED_METHOD',
        ),
      };
    } on CompanyApiException {
      rethrow;
    } on http.ClientException {
      throw const CompanyApiException(
        'Unable to reach PayMuster. Check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw CompanyApiException(
        'The server returned an invalid response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw CompanyApiException(
        'The server returned malformed data (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw CompanyApiException(
        'The server returned an unexpected response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final error = decoded['error'];
      final errorData = error is Map<String, dynamic> ? error : null;
      throw CompanyApiException(
        errorData?['message'] as String? ??
            'The company request failed (${response.statusCode}).',
        code: errorData?['code'] as String? ?? 'COMPANY_REQUEST_FAILED',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw CompanyApiException(
    'The server response is missing $field.',
    code: 'INVALID_RESPONSE',
  );
}

Map<String, dynamic> _mapValue(dynamic value, {required String field}) {
  if (value is Map<String, dynamic>) return value;
  throw CompanyApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

int _integerValue(dynamic value, {required String field}) {
  if (value is int) return value;
  throw CompanyApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

int _integerOrZero(dynamic value, {required String field}) {
  if (value == null) return 0;
  return _integerValue(value, field: field);
}

String _decimalString(dynamic value, {required String field}) {
  if (value == null) return '0';
  if (value is String && value.isNotEmpty) return value;
  if (value is int || value is double) return value.toString();
  throw CompanyApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

Map<String, dynamic> _mapValueOrEmpty(dynamic value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

Map<String, dynamic>? _mapValueOrNull(dynamic value) {
  return value is Map<String, dynamic> ? value : null;
}

String? _optionalString(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;
