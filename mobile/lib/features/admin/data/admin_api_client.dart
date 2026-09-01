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

  Future<Map<String, dynamic>> _delete(String path) {
    return _request('DELETE', path);
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
      'DELETE' => await _client.delete(uri, headers: headers),
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

  Future<Map<String, dynamic>> getProviderHealth() async {
    final res = await _get('/admin/providers/health');
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('The server returned invalid provider health data.');
    }
    final providers = data['providers'];
    if (providers is! List) {
      throw Exception('The server returned invalid provider health data.');
    }
    return {
      'providers': providers.cast<Map<String, dynamic>>(),
      'freeOnly': data['freeOnly'] == true,
    };
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

  /// Site detail: org, coordinates, assigned workers, site members,
  /// attendance counts and lifecycle timestamps — GET /admin/sites/:id.
  Future<Map<String, dynamic>> getSiteDetail(String siteId) async {
    final res = await _get('/admin/sites/$siteId');
    return res['data'] as Map<String, dynamic>? ?? const {};
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

  /// Server-authoritative recipient preview for the single announcement
  /// compose workflow: the exact recipient count (same filter as dispatch)
  /// plus a sample of who would be notified. Read-only.
  Future<AnnouncementPreview> previewAnnouncement(
    AnnouncementDispatchRequest request,
  ) async {
    final res = await _post('/admin/announcements/preview', request.toJson());
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('The server returned invalid preview data.');
    }
    return AnnouncementPreview.fromJson(data);
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

  Future<Map<String, dynamic>> sendAiPrompt(
    String prompt, {
    String? confirmationToken,
  }) async {
    final res = await _post('/admin/ai/chat', {
      'prompt': prompt,
      if (confirmationToken != null && confirmationToken.isNotEmpty)
        'confirmationToken': confirmationToken,
    });
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  // --- Subscriptions administration ---------------------------------------

  Future<Map<String, dynamic>> getSubscriptions({
    String? search,
    String? status,
    String? plan,
    String? trial,
    String? unlimited,
    int page = 1,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    if (plan != null && plan.isNotEmpty && plan != 'ALL') {
      params.add('plan=${Uri.encodeComponent(plan)}');
    }
    if (trial != null && trial.isNotEmpty && trial != 'ALL') {
      params.add('trial=${Uri.encodeComponent(trial)}');
    }
    if (unlimited != null && unlimited.isNotEmpty && unlimited != 'ALL') {
      params.add('unlimited=${Uri.encodeComponent(unlimited)}');
    }
    params.add('page=$page');
    params.add('limit=25');

    final queryString = '?${params.join('&')}';
    final res = await _get('/admin/subscriptions$queryString');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final subscribers = rawList
        .map((s) => AdminSubscriber.fromJson(s as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};
    final summary = meta['summary'] as Map<String, dynamic>?;

    return {
      'subscribers': subscribers,
      'total': meta['total'] ?? subscribers.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
      if (summary != null)
        'summary': AdminSubscriptionsSummary.fromJson(summary),
    };
  }

  Future<AdminSubscriptionDetail> getSubscriptionDetail(String orgId) async {
    final res = await _get('/admin/subscriptions/orgs/$orgId');
    return AdminSubscriptionDetail.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<List<AdminPlan>> getPlans() async {
    final res = await _get('/admin/subscriptions/plans');
    final rawList = res['data'] as List<dynamic>? ?? [];
    return rawList
        .map((p) => AdminPlan.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> grantUnlimited(String orgId) async {
    final res = await _post('/admin/subscription/orgs/$orgId/unlimited');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> revokeUnlimited(String orgId) async {
    final res = await _delete('/admin/subscription/orgs/$orgId/unlimited');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<bool> getSubscriptionSwitch() async {
    final res = await _get('/admin/subscription/switch');
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    return data['enabled'] as bool? ?? true;
  }

  Future<bool> setSubscriptionSwitch(bool enabled) async {
    final res = await _post('/admin/subscription/switch', {
      'enabled': enabled,
    });
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    return data['enabled'] as bool? ?? enabled;
  }

  Future<int> reconcileSubscriptions() async {
    final res = await _post('/admin/subscription/reconcile');
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    return (data['expiredCount'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> grantOffer(
    String orgId, {
    required String key,
    required dynamic value,
    String? expiresAt,
    String? note,
  }) async {
    final res = await _post('/admin/subscriptions/orgs/$orgId/offers', {
      'key': key,
      'value': value,
      if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  Future<Map<String, dynamic>> revokeOffer(String orgId, String key) async {
    final res = await _delete('/admin/subscriptions/orgs/$orgId/offers/$key');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  // --- Platform payments ---------------------------------------------------

  Future<Map<String, dynamic>> getPayments({
    String? search,
    String? status,
    int page = 1,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    params.add('page=$page');
    params.add('limit=25');

    final res = await _get('/admin/payments?${params.join('&')}');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final payments = rawList
        .map((p) => AdminPaymentEvent.fromJson(p as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'payments': payments,
      'total': meta['total'] ?? payments.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  Future<Map<String, dynamic>> getPaymentDetail(String id) async {
    final res = await _get('/admin/payments/$id');
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  // --- Platform mail supply --------------------------------------------------

  Future<AdminMailOverview> getMailOverview() async {
    final res = await _get('/admin/mail/overview');
    return AdminMailOverview.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminMailPreviewResult> previewPlatformMail({
    required String subject,
    required String body,
    required String targetType,
    String? targetRole,
    String? targetUserId,
    String? orgId,
  }) async {
    final res = await _post('/admin/mail/preview', {
      'subject': subject,
      'body': body,
      'targetType': targetType,
      if (targetRole != null && targetRole.isNotEmpty) 'targetRole': targetRole,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
      if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
    });
    return AdminMailPreviewResult.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminMailSendResult> sendPlatformMail({
    required String subject,
    required String body,
    required String targetType,
    String? targetRole,
    String? targetUserId,
    String? orgId,
  }) async {
    final res = await _post('/admin/mail/send', {
      'subject': subject,
      'body': body,
      'targetType': targetType,
      if (targetRole != null && targetRole.isNotEmpty) 'targetRole': targetRole,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
      if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
    });
    return AdminMailSendResult.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  // --- Platform announcements history -----------------------------------------

  Future<Map<String, dynamic>> getAnnouncementsAdmin({
    String? search,
    int page = 1,
  }) async {
    final params = <String>['page=$page', 'limit=25'];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    final res = await _get('/admin/announcements?${params.join('&')}');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final campaigns = rawList
        .map(
          (c) => AdminAnnouncementCampaign.fromJson(c as Map<String, dynamic>),
        )
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};

    return {
      'announcements': campaigns,
      'total': meta['total'] ?? campaigns.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  // --- Customer reviews --------------------------------------------------------

  Future<Map<String, dynamic>> getReviews({
    String? search,
    String? status,
    int page = 1,
  }) async {
    final params = <String>['page=$page', 'limit=25'];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params.add('status=${Uri.encodeComponent(status)}');
    }
    final res = await _get('/admin/reviews?${params.join('&')}');
    final rawList = res['data'] as List<dynamic>? ?? [];
    final reviews = rawList
        .map((r) => AdminReview.fromJson(r as Map<String, dynamic>))
        .toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? {};
    final summary = meta['summary'] as Map<String, dynamic>?;

    return {
      'reviews': reviews,
      'total': meta['total'] ?? reviews.length,
      'page': meta['page'] ?? page,
      'totalPages': meta['totalPages'] ?? 1,
      if (summary != null) 'summary': AdminReviewSummary.fromJson(summary),
    };
  }

  Future<AdminReviewSummary> getReviewSummary() async {
    final res = await _get('/admin/reviews/summary');
    return AdminReviewSummary.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminReview> getReviewDetail(String reviewId) async {
    final res = await _get('/admin/reviews/$reviewId');
    return AdminReview.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<Map<String, dynamic>> moderateReview(
    String reviewId, {
    required String action,
    String? response,
  }) async {
    final res = await _post('/admin/reviews/$reviewId/moderate', {
      'action': action,
      if (response != null && response.isNotEmpty) 'response': response,
    });
    return res['data'] as Map<String, dynamic>? ?? res;
  }

  // --- Reports / analytics --------------------------------------------------------

  Future<AdminReportsOverview> getReportsOverview() async {
    final res = await _get('/admin/reports/overview');
    return AdminReportsOverview.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
