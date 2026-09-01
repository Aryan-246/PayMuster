import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

/// One row from the recipient's notification center (GET /api/v1/notifications).
/// Scope is the authenticated user inside their current company; the client
/// cannot widen it.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.deepLink,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String? deepLink;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) {
      throw const TenantApiException(
        'The server returned invalid notification data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return AppNotification(
      id: id,
      title: title,
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'INFORMATION',
      deepLink: json['deepLink'] is String && (json['deepLink'] as String).isNotEmpty
          ? json['deepLink'] as String
          : null,
      readAt: json['readAt'] is String
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] is String
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime(1970))
          : DateTime(1970),
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.unread,
    required this.page,
    required this.totalPages,
  });

  final List<AppNotification> items;
  final int total;
  final int unread;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class NotificationCenterApi {
  const NotificationCenterApi(this._client);

  final TenantApiClient _client;

  Future<NotificationPage> list({
    int page = 1,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final envelope = await _client.getWithMeta(
      '/notifications',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (unreadOnly) 'unreadOnly': 'true',
      },
    );
    final rows = envelope.data;
    if (rows is! List) {
      throw const TenantApiException(
        'The server returned invalid notification data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return NotificationPage(
      items: rows
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(growable: false),
      total: envelope.intMeta('total') ?? 0,
      unread: envelope.intMeta('unread') ?? 0,
      page: envelope.intMeta('page') ?? page,
      totalPages: envelope.intMeta('totalPages') ?? 0,
    );
  }

  /// Idempotent on the server: marking an already-read row is a no-op.
  Future<void> markRead(String notificationId) async {
    await _client.post('/notifications/$notificationId/read', body: const {});
  }

  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all', body: const {});
  }
}

final notificationCenterApiProvider = Provider<NotificationCenterApi>((ref) {
  return NotificationCenterApi(ref.watch(tenantApiClientProvider));
});

/// Unread badge count for the shell. Refreshed by invalidation whenever the
/// user reads notifications.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final page = await ref.watch(notificationCenterApiProvider).list(limit: 1);
  return page.unread;
});
