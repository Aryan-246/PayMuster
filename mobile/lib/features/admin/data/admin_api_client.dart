import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';
import 'admin_models.dart';

final adminApiClientProvider = Provider<AdminApiClient>((ref) {
  final client = AdminApiClient(ref);
  ref.onDispose(client.close);
  return client;
});

class AdminApiClient {
  AdminApiClient(this.ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;

  void close() => _client.close();

  Future<Map<String, dynamic>> _get(String path) {
    return _request('GET', path);
  }

  Future<Map<String, dynamic>> _post(
    String path, [
    Map<String, dynamic>? body,
  ]) {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    final uri = Uri.parse('${Env.apiBaseUrl}/api/v1$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw ArgumentError.value(
        method,
        'method',
        'Unsupported HTTP method',
      ),
    };

    if (response.statusCode == 401 && canRetry) {
      final refreshed = await auth.refreshAccessToken();
      if (refreshed) {
        return _request(method, path, body: body, canRetry: false);
      }
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw Exception(
        'INVALID_RESPONSE: Expected JSON but received $contentType '
        '(Status: ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final errorData = decoded['error'] as Map<String, dynamic>?;
      throw Exception(
        errorData?['message'] ??
            decoded['message'] ??
            'Request failed with status ${response.statusCode}',
      );
    }
    return decoded;
  }

  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    final res = await _get('/admin/dashboard');
    return AdminDashboardMetrics.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getUsers({
    String? query,
    String? role,
    String? status,
    int page = 1,
  }) async {
    final params = <String>[];
    if (query != null && query.isNotEmpty) {
      params.add('q=${Uri.encodeComponent(query)}');
    }
    if (role != null && role.isNotEmpty) {
      params.add('role=${Uri.encodeComponent(role)}');
    }
    if (status != null && status.isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/users$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final users = rawList
        .map((u) => AdminUser.fromJson(u as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'users': users,
      'total': meta['total'] ?? users.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<AdminUserDetail> getUserById(String id) async {
    final res = await _get('/admin/users/$id');
    return AdminUserDetail.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> executeUserAction(
    String userId,
    String action, {
    String? role,
    String? reason,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (role != null) {
      body['role'] = role;
    }
    if (reason != null) {
      body['reason'] = reason;
    }
    final res = await _post('/admin/users/$userId/action', body);
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<String> resetUserPassword(String userId) async {
    final res = await _post('/admin/users/$userId/reset-password');
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final tempPassword = data['tempPassword'] as String?;
    if (tempPassword == null || tempPassword.isEmpty) {
      throw Exception('The server did not return a temporary password.');
    }
    return tempPassword;
  }

  Future<List<AdminOwnerRequest>> getOwnerRequests({String? status}) async {
    final query = (status != null && status.isNotEmpty)
        ? '?status=${Uri.encodeComponent(status)}'
        : '';
    final res = await _get('/admin/owner-requests$query');
    final rawList = res['data'] as List<dynamic>? ?? [];
    return rawList
        .map((r) => AdminOwnerRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> approveOwnerRequest(String requestId) async {
    final res = await _post('/admin/owner-requests/$requestId/approve');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> rejectOwnerRequest(
    String requestId, {
    String? reason,
  }) async {
    final res = await _post('/admin/owner-requests/$requestId/reject', {
      'reason': reason,
    });
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> getCompanies({
    String? search,
    int page = 1,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/companies$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final companies = rawList
        .map((c) => AdminCompany.fromJson(c as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'companies': companies,
      'total': meta['total'] ?? companies.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getCompanyDetail(String id) async {
    final res = await _get('/admin/companies/$id');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> getSites({
    String? search,
    String? orgId,
    int page = 1,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (orgId != null && orgId.isNotEmpty) {
      params.add('orgId=${Uri.encodeComponent(orgId)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/sites$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final sites = rawList
        .map((s) => AdminSite.fromJson(s as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'sites': sites,
      'total': meta['total'] ?? sites.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getAttendanceRecords({
    String? search,
    String? orgId,
    String? siteId,
    String? status,
    int page = 1,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (orgId != null && orgId.isNotEmpty) {
      params.add('orgId=${Uri.encodeComponent(orgId)}');
    }
    if (siteId != null && siteId.isNotEmpty) {
      params.add('siteId=${Uri.encodeComponent(siteId)}');
    }
    if (status != null && status.isNotEmpty) {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/attendance$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final records = rawList
        .map((r) => AdminAttendanceRecord.fromJson(r as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'records': records,
      'total': meta['total'] ?? records.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getPayrollRecords({
    String? orgId,
    int page = 1,
  }) async {
    final params = <String>[];
    if (orgId != null && orgId.isNotEmpty) {
      params.add('orgId=${Uri.encodeComponent(orgId)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/payroll$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final payRuns = rawList
        .map((pr) => AdminPayrollRecord.fromJson(pr as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'payRuns': payRuns,
      'total': meta['total'] ?? payRuns.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getAuditLogs({
    String? entityType,
    String? action,
    int page = 1,
  }) async {
    final params = <String>[];
    if (entityType != null && entityType.isNotEmpty) {
      params.add('entityType=${Uri.encodeComponent(entityType)}');
    }
    if (action != null && action.isNotEmpty) {
      params.add('action=${Uri.encodeComponent(action)}');
    }
    params.add('page=$page');
    params.add('limit=50');

    final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await _get('/admin/audit-logs$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final auditLogs = rawList
        .map((al) => AdminAuditLog.fromJson(al as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'auditLogs': auditLogs,
      'total': meta['total'] ?? auditLogs.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    final res = await _get('/admin/notifications?page=$page&limit=50');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final notifications = rawList
        .map((n) => AdminNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'notifications': notifications,
      'total': meta['total'] ?? notifications.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<AnnouncementDispatchResult> dispatchAnnouncement(
    AnnouncementDispatchRequest request,
  ) async {
    final res = await _post('/admin/announcements', request.toJson());
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('The server returned invalid campaign data.');
    }
    try {
      return AnnouncementDispatchResult.fromJson(data);
    } on FormatException {
      throw Exception('The server returned invalid campaign data.');
    }
  }

  Future<bool> getMaintenanceMode() async {
    final res = await _get('/admin/maintenance');
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    return data['enabled'] as bool? ?? false;
  }

  Future<void> setMaintenanceMode(bool enabled) async {
    await _post('/admin/maintenance/${enabled ? 'enable' : 'disable'}');
  }

  Future<List<Map<String, dynamic>>> getPendingDocuments() async {
    final res = await _get('/admin/documents/pending');
    final data = res['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> claimDocument(String documentId) async {
    final res = await _post('/admin/documents/$documentId/claim');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Uri> createDocumentViewUrl(String documentId) async {
    final res = await _post('/admin/documents/$documentId/view');
    final data = res['data'] as Map<String, dynamic>?;
    final rawUrl = data?['url'] as String?;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw Exception('The server did not return a valid document link.');
    }
    return uri;
  }

  Future<Map<String, dynamic>> verifyDocument(String documentId) async {
    final res = await _post('/admin/documents/$documentId/verify');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> rejectDocument(
    String documentId,
    String reason,
  ) async {
    final res = await _post('/admin/documents/$documentId/reject', {
      'reason': reason,
    });
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> sendAiPrompt(String prompt) async {
    final res = await _post('/admin/ai/chat', {'prompt': prompt});
    return res['data'] as Map<String, dynamic>? ?? res;
  }
}
