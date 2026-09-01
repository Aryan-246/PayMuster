import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/notifications/data/notification_api.dart';
import 'package:paymuster_mobile/features/ai/data/foundation_ai_api.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('parses unread notification with deep link', () {
      final notification = AppNotification.fromJson({
        'id': 'n-1',
        'title': 'Document reviewed',
        'body': 'Your Aadhaar was approved.',
        'type': 'DOCUMENT_REVIEW',
        'deepLink': '/app/notifications',
        'createdAt': '2026-08-29T10:00:00.000Z',
      });

      expect(notification.isRead, isFalse);
      expect(notification.deepLink, '/app/notifications');
      expect(notification.type, 'DOCUMENT_REVIEW');
    });

    test('parses read notification (readAt set) and blank deep links', () {
      final notification = AppNotification.fromJson({
        'id': 'n-2',
        'title': 'Announcement',
        'body': 'Site meeting at 9am',
        'type': 'ANNOUNCEMENT',
        'deepLink': '',
        'readAt': '2026-08-29T11:00:00.000Z',
        'createdAt': '2026-08-29T10:30:00.000Z',
      });

      expect(notification.isRead, isTrue);
      expect(notification.deepLink, isNull);
    });

    test('missing id fails loudly', () {
      expect(
        () => AppNotification.fromJson({'title': 'Broken'}),
        throwsA(isA<TenantApiException>()),
      );
    });
  });

  group('AiAnalysisResult.fromJson', () {
    test('parses analysis plus provider metadata', () {
      final result = AiAnalysisResult.fromJson({
        'analysis': 'Attendance was 94% this week.',
        'recommendation': null,
        'proposal': null,
        'confidence': null,
        'metadata': {
          'operation': 'QUERY',
          'provider': 'gemini',
          'model': 'gemini-2.5-flash',
          'generatedAt': '2026-08-29T10:00:00.000Z',
          'mutationsAllowed': false,
        },
      });

      expect(result.analysis, 'Attendance was 94% this week.');
      expect(result.operation, 'QUERY');
      expect(result.provider, 'gemini');
    });

    test('empty analysis is an error, never rendered as a fake answer', () {
      expect(
        () => AiAnalysisResult.fromJson({
          'analysis': '',
          'metadata': <String, dynamic>{},
        }),
        throwsA(isA<TenantApiException>()),
      );
    });
  });
}
