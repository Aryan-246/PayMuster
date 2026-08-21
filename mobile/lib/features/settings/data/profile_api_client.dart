import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';

final profileApiProvider = Provider<ProfileApiClient>((ref) {
  return ProfileApiClient(ref);
});

class ProfileApiException implements Exception {
  const ProfileApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProfileSnapshot {
  const ProfileSnapshot({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.documents,
    required this.verification,
    this.publicId,
    this.phone,
    this.organization,
    this.avatarUrl,
  });

  final String id;
  final String? publicId;
  final String email;
  final String? phone;
  final String name;
  final String role;
  final String status;
  final ProfileOrganization? organization;
  final Uri? avatarUrl;
  final List<ProfileDocument> documents;
  final ProfileVerification verification;

  factory ProfileSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDocuments = json['documents'] as List<dynamic>? ?? const [];
    return ProfileSnapshot(
      id: json['id'] as String,
      publicId: json['publicId'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      name: json['name'] as String? ?? 'User',
      role: json['role'] as String? ?? 'STAFF',
      status: json['status'] as String? ?? 'PENDING',
      organization: json['organization'] is Map<String, dynamic>
          ? ProfileOrganization.fromJson(
              json['organization'] as Map<String, dynamic>,
            )
          : null,
      avatarUrl: _httpsUri(json['avatarUrl']),
      documents: rawDocuments
          .whereType<Map<String, dynamic>>()
          .map(ProfileDocument.fromJson)
          .toList(growable: false),
      verification: ProfileVerification.fromJson(
        json['verification'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ProfileOrganization {
  const ProfileOrganization({
    required this.id,
    required this.name,
    this.publicId,
  });

  final String id;
  final String name;
  final String? publicId;

  factory ProfileOrganization.fromJson(Map<String, dynamic> json) {
    return ProfileOrganization(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Organization unavailable',
      publicId: json['publicId'] as String?,
    );
  }
}

class ProfileDocument {
  const ProfileDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.version,
    this.rejectionReason,
  });

  final String id;
  final String type;
  final String status;
  final int version;
  final String? rejectionReason;

  factory ProfileDocument.fromJson(Map<String, dynamic> json) {
    return ProfileDocument(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'Document',
      status: json['status'] as String? ?? 'PENDING_REVIEW',
      version: (json['version'] as num?)?.toInt() ?? 1,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}

class ProfileVerification {
  const ProfileVerification({
    required this.total,
    required this.verified,
    required this.pending,
    required this.rejected,
  });

  final int total;
  final int verified;
  final int pending;
  final int rejected;

  factory ProfileVerification.fromJson(Map<String, dynamic> json) {
    return ProfileVerification(
      total: (json['total'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileApiClient {
  ProfileApiClient(this.ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref ref;
  final http.Client _client;

  Future<ProfileSnapshot> getProfile() => _jsonRequest('GET');

  Future<ProfileSnapshot> updateProfile({required String name, String? phone}) {
    return _jsonRequest('PATCH', body: {'name': name, 'phone': phone});
  }

  Future<ProfileSnapshot> uploadAvatar({
    required Uint8List bytes,
    required String mimeType,
  }) {
    return _avatarRequest(bytes: bytes, mimeType: mimeType);
  }

  Future<ProfileSnapshot> _jsonRequest(
    String method, {
    Map<String, dynamic>? body,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ProfileApiException(
        'Your session has expired. Please sign in again.',
        code: 'SESSION_EXPIRED',
        statusCode: 401,
      );
    }
    final uri = Uri.parse('${Env.apiBaseUrl}/api/v1/profile');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.patch(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _jsonRequest(method, body: body, canRetry: false);
    }
    return _decode(response);
  }

  Future<ProfileSnapshot> _avatarRequest({
    required Uint8List bytes,
    required String mimeType,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ProfileApiException('Your session has expired.');
    }
    final response = await _client.post(
      Uri.parse('${Env.apiBaseUrl}/api/v1/profile/avatar'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': mimeType},
      body: bytes,
    );
    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _avatarRequest(bytes: bytes, mimeType: mimeType, canRetry: false);
    }
    return _decode(response);
  }

  ProfileSnapshot _decode(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw ProfileApiException(
        'The server returned an invalid response (${response.statusCode}).',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ProfileApiException(
        error?['message'] as String? ?? 'The profile request failed.',
        code: error?['code'] as String?,
        statusCode: response.statusCode,
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ProfileApiException(
        'The server returned invalid profile data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return ProfileSnapshot.fromJson(data);
  }
}

Uri? _httpsUri(dynamic value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri
      : null;
}
