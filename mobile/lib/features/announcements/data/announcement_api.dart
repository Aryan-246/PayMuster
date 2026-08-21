import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';

final announcementApiProvider = Provider<AnnouncementDataSource>((ref) {
  final client = AnnouncementApiClient(ref);
  ref.onDispose(client.close);
  return client;
});

final announcementsProvider = FutureProvider<AnnouncementPage>((ref) {
  return ref.watch(announcementApiProvider).listAnnouncements(limit: 100);
});

abstract interface class AnnouncementDataSource {
  Future<AnnouncementPage> listAnnouncements({int page = 1, int limit = 50});

  Future<AnnouncementAcknowledgement> acknowledge(String announcementId);

  Stream<AnnouncementInvalidation> watchInvalidations();
}

class AnnouncementApiException implements Exception {
  const AnnouncementApiException(
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

class AnnouncementApiClient implements AnnouncementDataSource {
  AnnouncementApiClient(this.ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;

  void close() => _client.close();

  @override
  Future<AnnouncementPage> listAnnouncements({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _request(
      'GET',
      '/announcements',
      query: {'page': page.toString(), 'limit': limit.toString()},
    );
    final rawData = response['data'];
    final meta = _requiredMap(response['meta'], 'meta');
    if (rawData is! List) {
      throw const AnnouncementApiException(
        'The server returned invalid announcement data.',
        code: 'INVALID_RESPONSE',
      );
    }

    return AnnouncementPage(
      announcements: rawData
          .map(
            (item) => Announcement.fromJson(_requiredMap(item, 'announcement')),
          )
          .toList(growable: false),
      total: _requiredInt(meta, 'total'),
      unread: _requiredInt(meta, 'unread'),
      page: _requiredInt(meta, 'page'),
      totalPages: _requiredInt(meta, 'totalPages'),
    );
  }

  @override
  Future<AnnouncementAcknowledgement> acknowledge(String announcementId) async {
    final response = await _request(
      'POST',
      '/announcements/${Uri.encodeComponent(announcementId)}/acknowledge',
      body: const <String, dynamic>{},
    );
    return AnnouncementAcknowledgement.fromJson(
      _requiredMap(response['data'], 'acknowledgement'),
    );
  }

  @override
  Stream<AnnouncementInvalidation> watchInvalidations() async* {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const AnnouncementApiException(
        'Your session has expired. Please sign in again.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
      );
    }

    final request = http.Request(
      'GET',
      Uri.parse('${Env.apiBaseUrl}/api/v1/announcements/stream'),
    )..headers['Authorization'] = 'Bearer $token';

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on http.ClientException {
      throw const AnnouncementApiException(
        'Unable to reach PayMuster. Check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }

    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw _streamError(response.statusCode, body);
    }

    var eventName = '';
    final dataLines = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (eventName == 'announcements-invalidated' && dataLines.isNotEmpty) {
          final decoded = _decodeObject(dataLines.join('\n'));
          yield AnnouncementInvalidation.fromJson(decoded);
        }
        eventName = '';
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const AnnouncementApiException(
        'Your session has expired. Please sign in again.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
      );
    }

    final uri = Uri.parse(
      '${Env.apiBaseUrl}/api/v1$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    late final http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ),
        _ => throw AnnouncementApiException(
          'Unsupported request method: $method',
          code: 'UNSUPPORTED_METHOD',
        ),
      };
    } on AnnouncementApiException {
      rethrow;
    } on http.ClientException {
      throw const AnnouncementApiException(
        'Unable to reach PayMuster. Check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }

    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _request(method, path, query: query, body: body, canRetry: false);
    }

    final decoded = _decodeResponse(response);
    if (response.statusCode >= 400) {
      final error = decoded['error'];
      final errorMap = error is Map<String, dynamic> ? error : null;
      throw AnnouncementApiException(
        errorMap?['message'] as String? ??
            'The request failed (${response.statusCode}).',
        code: errorMap?['code'] as String? ?? 'ANNOUNCEMENT_REQUEST_FAILED',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw AnnouncementApiException(
        'The server returned an invalid response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
    try {
      return _decodeObject(response.body);
    } on FormatException {
      throw AnnouncementApiException(
        'The server returned malformed data (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
  }

  AnnouncementApiException _streamError(int statusCode, String body) {
    try {
      final decoded = _decodeObject(body);
      final error = decoded['error'];
      final errorMap = error is Map<String, dynamic> ? error : null;
      return AnnouncementApiException(
        errorMap?['message'] as String? ??
            'The announcement stream failed ($statusCode).',
        code: errorMap?['code'] as String? ?? 'ANNOUNCEMENT_STREAM_FAILED',
        statusCode: statusCode,
      );
    } on FormatException {
      return AnnouncementApiException(
        'The announcement stream failed ($statusCode).',
        code: 'ANNOUNCEMENT_STREAM_FAILED',
        statusCode: statusCode,
      );
    }
  }
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.announcements,
    required this.total,
    required this.unread,
    required this.page,
    required this.totalPages,
  });

  final List<Announcement> announcements;
  final int total;
  final int unread;
  final int page;
  final int totalPages;
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.deepLink,
    this.acknowledgedAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String? deepLink;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;

  bool get isAcknowledged => acknowledgedAt != null;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'] as Map<String, dynamic>?;
    return Announcement(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
      type: campaign?['type'] as String? ?? 'INFORMATION',
      deepLink: _validInternalLink(json['deepLink']),
      acknowledgedAt: _optionalDate(json['readAt'], 'readAt'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

class AnnouncementAcknowledgement {
  const AnnouncementAcknowledgement({
    required this.id,
    required this.acknowledgedAt,
    required this.changed,
  });

  final String id;
  final DateTime acknowledgedAt;
  final bool changed;

  factory AnnouncementAcknowledgement.fromJson(Map<String, dynamic> json) {
    final changed = json['changed'];
    if (changed is! bool) {
      throw const AnnouncementApiException(
        'The server returned invalid acknowledgement data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return AnnouncementAcknowledgement(
      id: _requiredString(json, 'id'),
      acknowledgedAt: _requiredDate(json, 'acknowledgedAt'),
      changed: changed,
    );
  }
}

class AnnouncementInvalidation {
  const AnnouncementInvalidation({
    required this.reason,
    required this.occurredAt,
  });

  final String reason;
  final DateTime occurredAt;

  factory AnnouncementInvalidation.fromJson(Map<String, dynamic> json) {
    return AnnouncementInvalidation(
      reason: _requiredString(json, 'reason'),
      occurredAt: _requiredDate(json, 'occurredAt'),
    );
  }
}

Map<String, dynamic> _decodeObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return decoded;
}

Map<String, dynamic> _requiredMap(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw AnnouncementApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw AnnouncementApiException(
    'The server response is missing $field.',
    code: 'INVALID_RESPONSE',
  );
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw AnnouncementApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String field) {
  final value = _optionalDate(json[field], field);
  if (value != null) return value;
  throw AnnouncementApiException(
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
  throw AnnouncementApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

String? _validInternalLink(dynamic value) {
  if (value == null) return null;
  if (value is String && value.startsWith('/app/') && !value.startsWith('//')) {
    return value;
  }
  throw const AnnouncementApiException(
    'The server response contains an invalid announcement link.',
    code: 'INVALID_RESPONSE',
  );
}
