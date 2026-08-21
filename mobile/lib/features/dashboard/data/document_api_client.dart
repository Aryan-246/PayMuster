import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';

final documentApiClientProvider = Provider<DocumentApiClient>((ref) {
  return DocumentApiClient(ref);
});

class StaffDocumentSummary {
  const StaffDocumentSummary({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.expiryDate,
    this.reviewerId,
    this.reviewedAt,
    this.rejectionReason,
    this.version = 1,
    this.parentDocumentId,
    this.resubmissionCount = 0,
    this.originalFilename,
    this.mimeType,
    this.byteSize,
  });

  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiryDate;
  final String? reviewerId;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final int version;
  final String? parentDocumentId;
  final int resubmissionCount;
  final String? originalFilename;
  final String? mimeType;
  final int? byteSize;

  factory StaffDocumentSummary.fromJson(Map<String, dynamic> json) {
    return StaffDocumentSummary(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'Document',
      status: json['status'] as String? ?? 'PENDING_REVIEW',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      reviewerId: json['reviewerId'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      parentDocumentId: json['parentDocumentId'] as String?,
      resubmissionCount: (json['resubmissionCount'] as num?)?.toInt() ?? 0,
      originalFilename: json['originalFilename'] as String?,
      mimeType: json['mimeType'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
    );
  }
}

class DocumentApiClient {
  DocumentApiClient(this.ref);

  final Ref ref;

  Future<List<StaffDocumentSummary>> listMine() async {
    final response = await _jsonRequest('GET', '/documents');
    final data = response['data'] as List<dynamic>? ?? const [];
    return data
        .map(
          (item) => StaffDocumentSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<StaffDocumentSummary> upload({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String documentType,
    DateTime? expiryDate,
    String? parentDocumentId,
  }) async {
    final parentHeaders = parentDocumentId == null
        ? const <String, String>{}
        : <String, String>{'X-Parent-Document-Id': parentDocumentId};
    final expiryHeaders = expiryDate == null
        ? const <String, String>{}
        : <String, String>{
            'X-Expiry-Date': DateTime.utc(
              expiryDate.year,
              expiryDate.month,
              expiryDate.day,
            ).toIso8601String(),
          };
    final response = await _binaryRequest(
      '/documents',
      bytes: bytes,
      headers: {
        'Content-Type': mimeType,
        'X-Document-Type': documentType,
        'X-File-Name': filename,
        ...parentHeaders,
        ...expiryHeaders,
      },
    );
    return StaffDocumentSummary.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<Uri> createViewUrl(String documentId) async {
    final response = await _jsonRequest('POST', '/documents/$documentId/view');
    final data = response['data'] as Map<String, dynamic>?;
    final rawUrl = data?['url'] as String?;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw Exception('The server did not return a valid document link.');
    }
    return uri;
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    final uri = Uri.parse('${Env.apiBaseUrl}/api/v1$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = method == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers);

    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _jsonRequest(method, path, canRetry: false);
    }
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _binaryRequest(
    String path, {
    required Uint8List bytes,
    required Map<String, String> headers,
    bool canRetry = true,
  }) async {
    final auth = ref.read(authProvider);
    final token = await auth.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    final response = await http.post(
      Uri.parse('${Env.apiBaseUrl}/api/v1$path'),
      headers: {...headers, 'Authorization': 'Bearer $token'},
      body: bytes,
    );
    if (response.statusCode == 401 &&
        canRetry &&
        await auth.refreshAccessToken()) {
      return _binaryRequest(
        path,
        bytes: bytes,
        headers: headers,
        canRetry: false,
      );
    }
    return _decodeJson(response);
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw Exception(
        'The server returned an invalid response (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw Exception(
        error?['message'] as String? ??
            'The document request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }
}
