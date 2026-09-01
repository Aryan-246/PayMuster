import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_provider.dart';
import '../active_company_provider.dart';
import '../env/env.dart';
import '../observability/observability_reporter.dart';

final tenantApiClientProvider = Provider<TenantApiClient>((ref) {
  final client = TenantApiClient(ref);
  ref.onDispose(client.close);
  return client;
});

class TenantApiException implements Exception {
  const TenantApiException(
    this.message, {
    required this.code,
    this.statusCode,
    this.requestId,
  });

  final String message;
  final String code;
  final int? statusCode;
  final String? requestId;

  @override
  String toString() => message;
}

/// A successful envelope: `data` plus the endpoint's `meta` block.
class TenantApiEnvelope {
  const TenantApiEnvelope({required this.data, required this.meta});

  final dynamic data;
  final Map<String, dynamic> meta;

  int? intMeta(String key) {
    final value = meta[key];
    return value is int ? value : value is num ? value.toInt() : null;
  }
}

class TenantApiClient {
  TenantApiClient(this.ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;

  void close() => _client.close();

  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
  }) {
    return _request('GET', path, query: query);
  }

  /// Authenticated GET that keeps the response envelope's `meta` block
  /// (total / page / totalPages / unread …) alongside `data` — required by
  /// paginated list screens. Non-2xx responses throw exactly like `get`.
  Future<TenantApiEnvelope> getWithMeta(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    final envelope = await _request('GET', path, query: query, keepMeta: true);
    if (envelope is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The server returned an unexpected response.',
        code: 'INVALID_RESPONSE',
      );
    }
    return TenantApiEnvelope(
      data: envelope['data'],
      meta: envelope['meta'] is Map<String, dynamic>
          ? envelope['meta'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  /// Authenticated GET that does NOT require a company context — for
  /// cross-company reads such as the user's switchable companies. No
  /// x-company-id header is sent; the endpoint re-authenticates the user.
  Future<dynamic> getWithoutTenant(String path) {
    return _request('GET', path, requireTenant: false);
  }

  Future<dynamic> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> extraHeaders = const {},
  }) {
    return _request('POST', path, body: body, extraHeaders: extraHeaders);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    bool canRetry = true,
    bool requireTenant = true,
    bool keepMeta = false,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const TenantApiException(
        'Your session has expired. Please sign in again.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
      );
    }

    String? organizationId;
    if (requireTenant) {
      var user = await auth.getCurrentUser();
      if (user?.organizationId == null) {
        try {
          user = await auth.fetchMe();
        } catch (_) {
          throw const TenantApiException(
            'A company must be selected before using this feature.',
            code: 'COMPANY_CONTEXT_REQUIRED',
            statusCode: 403,
          );
        }
      }
      organizationId = ref.read(activeCompanyProvider) ?? user?.organizationId;
      if (organizationId == null || organizationId.isEmpty) {
        throw const TenantApiException(
          'A company must be selected before using this feature.',
          code: 'COMPANY_CONTEXT_REQUIRED',
          statusCode: 403,
        );
      }
    }

    final queryParameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    final uri = Uri.parse('${Env.apiBaseUrl}/api/v1$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final baseHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'x-company-id': ?organizationId,
    };

    late final http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(
          uri,
          headers: {...baseHeaders, ...extraHeaders},
        ),
        'POST' => await _client.post(
          uri,
          headers: {...baseHeaders, ...extraHeaders},
          body: jsonEncode(body),
        ),
        _ => throw TenantApiException(
          'Unsupported request method: $method',
          code: 'UNSUPPORTED_METHOD',
        ),
      };
    } on TenantApiException catch (error) {
      await _report(error, path);
      rethrow;
    } on http.ClientException catch (error, stack) {
      final apiError = TenantApiException(
        'Unable to reach PayMuster. Check your connection and try again.',
        code: 'NETWORK_ERROR',
        statusCode: null,
      );
      await _report(apiError, path, error: error, stack: stack);
      throw apiError;
    }

    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _request(
        method,
        path,
        query: query,
        body: body,
        extraHeaders: extraHeaders,
        canRetry: false,
        requireTenant: requireTenant,
        keepMeta: keepMeta,
      );
    }

    try {
      final decoded = _decode(response);
      if (keepMeta) return decoded;
      return decoded.containsKey('data') ? decoded['data'] : decoded;
    } on TenantApiException catch (error) {
      await _report(error, path);
      rethrow;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final requestId = response.headers['x-request-id'];
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw TenantApiException(
        'The server returned an invalid response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw TenantApiException(
        'The server returned malformed data (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw TenantApiException(
        'The server returned an unexpected response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }

    if (response.statusCode >= 400) {
      final rawError = decoded['error'];
      final error = rawError is Map<String, dynamic> ? rawError : null;
      throw TenantApiException(
        error?['message'] as String? ??
            'The request failed (${response.statusCode}).',
        code: error?['code'] as String? ?? 'TENANT_REQUEST_FAILED',
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    return decoded;
  }

  Future<void> _report(
    TenantApiException apiError,
    String path, {
    Object? error,
    StackTrace? stack,
  }) {
    return ObservabilityReporter().reportError(
      error ?? apiError,
      stack ?? StackTrace.current,
      requestId: apiError.requestId,
      operation: 'tenantApi $path',
    );
  }
}
