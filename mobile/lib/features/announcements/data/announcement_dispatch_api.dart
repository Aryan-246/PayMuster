import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final announcementDispatchApiProvider = Provider<AnnouncementDispatchApi>((ref) {
  return AnnouncementDispatchApi(ref.read(tenantApiClientProvider));
});

class AnnouncementDispatchResult {
  const AnnouncementDispatchResult({
    required this.campaignId,
    required this.audience,
    required this.orgId,
    required this.recipientCount,
    required this.createdAt,
  });

  final String campaignId;
  final String audience;
  final String orgId;
  final int recipientCount;
  final DateTime createdAt;

  factory AnnouncementDispatchResult.fromJson(Map<String, dynamic> json) {
    return AnnouncementDispatchResult(
      campaignId: _requiredString(json, 'campaignId'),
      audience: _requiredString(json, 'audience'),
      orgId: _requiredString(json, 'orgId'),
      recipientCount: _requiredInt(json, 'recipientCount'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

/// Org-scoped announcement dispatch — POST /api/v1/announcements/dispatch
/// (manage_announcements + COMPANY tenant scope enforced server-side; the
/// org is forced to the actor's org, so a client orgId is never trusted).
class AnnouncementDispatchApi {
  AnnouncementDispatchApi(this._client);

  final TenantApiClient _client;

  Future<AnnouncementDispatchResult> dispatch({
    required String title,
    required String body,
    required String type,
    required String audience,
    String? deepLink,
    String? audienceRole,
    String? audienceUserId,
  }) async {
    final data = await _client.post(
      '/announcements/dispatch',
      body: {
        'title': title,
        'body': body,
        'type': type,
        'audience': audience,
        if (deepLink != null && deepLink.isNotEmpty) 'deepLink': deepLink,
        if (audienceRole != null && audience == 'ROLE')
          'audienceRole': audienceRole,
        if (audienceUserId != null && audience == 'USER')
          'audienceUserId': audienceUserId,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The announcement dispatch response was invalid.',
        code: 'INVALID_ANNOUNCEMENT_RESPONSE',
      );
    }
    return AnnouncementDispatchResult.fromJson(data);
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw TenantApiException(
    'The announcement dispatch response has an invalid $key.',
    code: 'INVALID_ANNOUNCEMENT_RESPONSE',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw TenantApiException(
    'The announcement dispatch response has an invalid $key.',
    code: 'INVALID_ANNOUNCEMENT_RESPONSE',
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The announcement dispatch response is missing $key.',
    code: 'INVALID_ANNOUNCEMENT_RESPONSE',
  );
}
