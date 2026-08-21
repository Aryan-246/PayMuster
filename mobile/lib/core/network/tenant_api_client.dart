import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_provider.dart';
import '../env/env.dart';

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
  });

  final String message;
  final String code;
  final int? statusCode;

  @override
  String toString() => message;
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

  Future<dynamic> post(String path, {required Map<String, dynamic> body}) {
    return _request('POST', path, body: body);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Map<String, dynamic>? body,
    bool canRetry = true,
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
    final organizationId = user?.organizationId;
    if (organizationId == null || organizationId.isEmpty) {
      throw const TenantApiException(
        'A company must be selected before using this feature.',
        code: 'COMPANY_CONTEXT_REQUIRED',
        statusCode: 403,
      );
    }

    final queryParameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    final uri = Uri.parse('${Env.apiBaseUrl}/api/v1$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    late final http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'x-company-id': organizationId,
          },
        ),
        'POST' => await _client.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'x-company-id': organizationId,
          },
          body: jsonEncode(body),
        ),
        _ => throw TenantApiException(
          'Unsupported request method: $method',
          code: 'UNSUPPORTED_METHOD',
        ),
      };
    } on TenantApiException {
      rethrow;
    } on http.ClientException {
      throw const TenantApiException(
        'Unable to reach PayMuster. Check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }

    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _request(
        method,
        path,
        query: query,
        body: body,
        canRetry: false,
      );
    }

    final decoded = _decode(response);
    return decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw TenantApiException(
        'The server returned an invalid response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
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
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw TenantApiException(
        'The server returned an unexpected response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
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
      );
    }
    return decoded;
  }
}
