import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final mailSupplyApiProvider = Provider<MailSupplyApi>((ref) {
  return MailSupplyApi(ref.read(tenantApiClientProvider));
});

class MailUsage {
  const MailUsage({
    required this.sent,
    required this.limit,
    required this.remaining,
    required this.monthKey,
  });

  final int sent;
  final int limit;
  final int remaining;
  final String monthKey;

  bool get unlimited => limit >= 999999;

  factory MailUsage.fromJson(Map<String, dynamic> json) {
    return MailUsage(
      sent: _requiredInt(json, 'sent'),
      limit: _requiredInt(json, 'limit'),
      remaining: _requiredInt(json, 'remaining'),
      monthKey: _requiredString(json, 'monthKey'),
    );
  }
}

class MailDispatchEntry {
  const MailDispatchEntry({
    required this.id,
    required this.sentAt,
    required this.subject,
    required this.targetType,
    required this.recipientCount,
    required this.status,
  });

  final String id;
  final DateTime sentAt;
  final String subject;
  final String targetType;
  final int recipientCount;
  final String status;

  factory MailDispatchEntry.fromJson(Map<String, dynamic> json) {
    return MailDispatchEntry(
      id: _requiredString(json, 'id'),
      sentAt: _requiredDate(json, 'sentAt'),
      subject: _requiredString(json, 'subject'),
      targetType: _requiredString(json, 'targetType'),
      recipientCount: _requiredInt(json, 'recipientCount'),
      status: _requiredString(json, 'status'),
    );
  }
}

class MailSendResult {
  const MailSendResult({
    required this.sent,
    required this.failed,
    required this.dispatchId,
    this.duplicate = false,
  });

  final int sent;
  final int failed;
  final String dispatchId;
  final bool duplicate;

  factory MailSendResult.fromJson(Map<String, dynamic> json) {
    return MailSendResult(
      sent: _requiredInt(json, 'sent'),
      failed: _requiredInt(json, 'failed'),
      dispatchId: json['dispatchId'] is String ? json['dispatchId'] as String : '',
      duplicate: json['duplicate'] == true,
    );
  }
}

/// Mail Supply API — GET/POST /api/v1/mail-supply/* (manage_mail + COMPANY
/// tenant scope enforced server-side; orgId travels in x-company-id only).
class MailSupplyApi {
  MailSupplyApi(this._client);

  final TenantApiClient _client;

  Future<MailUsage> getUsage() async {
    final data = await _client.get('/mail-supply/usage');
    return MailUsage.fromJson(_map(data));
  }

  Future<List<MailDispatchEntry>> getHistory({int limit = 50}) async {
    final data = await _client.get(
      '/mail-supply/history',
      query: {'limit': limit.toString()},
    );
    if (data is! List) {
      throw const TenantApiException(
        'The mail history response was invalid.',
        code: 'INVALID_MAIL_RESPONSE',
      );
    }
    return data
        .map((item) => MailDispatchEntry.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<MailSendResult> send({
    required String subject,
    required String body,
    required String targetType,
    String? targetRole,
    String? targetUserId,
    required String idempotencyKey,
  }) async {
    final data = await _client.post(
      '/mail-supply/send',
      body: {
        'subject': subject,
        'body': body,
        'targetType': targetType,
        if (targetRole != null && targetType == 'ROLE') 'targetRole': targetRole,
        if (targetUserId != null && targetType == 'INDIVIDUAL')
          'targetUserId': targetUserId,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return MailSendResult.fromJson(_map(data));
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw const TenantApiException(
      'The mail supply response was invalid.',
      code: 'INVALID_MAIL_RESPONSE',
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw TenantApiException(
    'The mail supply response has an invalid $key.',
    code: 'INVALID_MAIL_RESPONSE',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw TenantApiException(
    'The mail supply response has an invalid $key.',
    code: 'INVALID_MAIL_RESPONSE',
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The mail supply response is missing $key.',
    code: 'INVALID_MAIL_RESPONSE',
  );
}
