import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/features/admin/data/admin_models.dart';

void main() {
  group('AdminPayrollRecord.fromJson', () {
    Map<String, dynamic> payload(Object totalAmount) => {
      'id': 'pay-run-1',
      'publicId': 'PM-PR-000001',
      'totalAmount': totalAmount,
      'org': {'name': 'Example Company', 'publicId': 'PM-CMP-000001'},
      'payCycle': {
        'startDate': '2026-08-01',
        'endDate': '2026-08-15',
        'status': 'CALCULATED',
      },
      '_count': {'payRunItems': 2},
    };

    test('parses numeric decimal payloads', () {
      final record = AdminPayrollRecord.fromJson(payload(15000));

      expect(record.totalAmount, 15000.0);
    });

    test('parses string decimal payloads from serialized Decimal values', () {
      final record = AdminPayrollRecord.fromJson(payload('15000'));

      expect(record.totalAmount, 15000.0);
    });

    test('defaults malformed amounts to zero', () {
      final record = AdminPayrollRecord.fromJson(payload('not-a-number'));

      expect(record.totalAmount, 0.0);
    });
  });

  group('AdminSubscriber.fromJson', () {
    Map<String, dynamic> payload({Map<String, dynamic>? owner}) => {
          'id': 'sub-1',
          'orgId': 'org-1',
          'org': {'id': 'org-1', 'name': 'Acme Construction', 'publicId': 'PM-CMP-000001'},
          'owner': owner,
          'plan': {
            'code': 'PRO',
            'name': 'Pro',
            'amountMinor': 99900,
            'currency': 'INR',
          },
          'status': 'ACTIVE',
          'provider': 'razorpay',
          'unlimitedAccess': false,
          'cancelAtPeriodEnd': false,
          'currentPeriodEnd': '2026-09-30T00:00:00.000Z',
          'createdAt': '2026-08-01T00:00:00.000Z',
        };

    test('derives the owner name from first/last with email fallback', () {
      final named = AdminSubscriber.fromJson(payload(owner: {
        'publicId': 'PM-USR-000009',
        'firstName': 'Asha',
        'lastName': 'Verma',
        'email': 'asha@example.com',
      }));
      expect(named.ownerName, 'Asha Verma');
      expect(named.ownerPublicId, 'PM-USR-000009');

      final emailOnly = AdminSubscriber.fromJson(payload(owner: {
        'publicId': 'PM-USR-000010',
        'firstName': '',
        'lastName': null,
        'email': 'me@example.com',
      }));
      expect(emailOnly.ownerName, 'me@example.com');

      final none = AdminSubscriber.fromJson(payload());
      expect(none.ownerName, isNull);
    });

    test('maps plan + status fields through', () {
      final s = AdminSubscriber.fromJson(payload());
      expect(s.planCode, 'PRO');
      expect(s.planName, 'Pro');
      expect(s.status, 'ACTIVE');
      expect(s.orgName, 'Acme Construction');
      expect(s.orgPublicId, 'PM-CMP-000001');
      expect(s.isPaid, isTrue);
    });
  });

  group('AdminReview.fromJson', () {
    test('parses user, org and moderation state', () {
      final r = AdminReview.fromJson({
        'id': 'rev-1',
        'publicId': 'PM-REV-000001',
        'rating': 4,
        'text': 'Solid payroll experience.',
        'status': 'PUBLISHED',
        'createdAt': '2026-08-15T10:00:00.000Z',
        'adminResponse': 'Thank you!',
        'moderatedAt': '2026-08-16T10:00:00.000Z',
        'user': {
          'publicId': 'PM-USR-000004',
          'firstName': 'Ravi',
          'lastName': 'K',
          'email': 'ravi@example.com',
          'role': 'OWNER',
        },
        'org': {'name': 'Acme', 'publicId': 'PM-CMP-000001'},
      });

      expect(r.rating, 4);
      expect(r.status, 'PUBLISHED');
      expect(r.userName, 'Ravi K');
      expect(r.orgName, 'Acme');
      expect(r.adminResponse, 'Thank you!');
    });

    test('falls back to email when the user has no name', () {
      final r = AdminReview.fromJson({
        'id': 'rev-2',
        'rating': 5,
        'text': 'Great',
        'status': 'PENDING',
        'createdAt': '2026-08-15T10:00:00.000Z',
        'user': <String, dynamic>{'email': 'anon@example.com'},
        'org': <String, dynamic>{},
      });

      expect(r.userName, 'anon@example.com');
      expect(r.userPublicId, isNull);
    });
  });

  group('AdminReviewSummary.fromJson', () {
    test('parses the distribution keyed by star with junk keys dropped', () {
      final s = AdminReviewSummary.fromJson({
        'total': 10,
        'average': 3.5,
        'distribution': {'1': 2, '4': 5, '5': 3, '9': 7},
        'pendingCount': 3,
        'publishedCount': 4,
        'hiddenCount': 2,
        'flaggedCount': 1,
      });

      expect(s.total, 10);
      expect(s.average, 3.5);
      expect(s.distribution, {1: 2, 4: 5, 5: 3});
      expect(s.pendingCount, 3);
      expect(s.publishedCount, 4);
      expect(s.hiddenCount, 2);
      expect(s.flaggedCount, 1);
    });

    test('handles an empty summary honestly', () {
      final s = AdminReviewSummary.fromJson({});
      expect(s.total, 0);
      expect(s.average, 0);
      expect(s.distribution, isEmpty);
    });
  });

  group('AdminReportsOverview.fromJson', () {
    test('collects and sorts the union of series days', () {
      final o = AdminReportsOverview.fromJson({
        'totals': {'users': 5, 'mailSent': 12},
        'series': {
          'users': {'2026-08-02': 1, '2026-08-01': 2},
          'payments': {'2026-08-03': 1},
        },
      });

      expect(o.totals['users'], 5);
      expect(o.totals['mailSent'], 12);
      expect(o.series['users']!['2026-08-01'], 2);
      expect(o.days, ['2026-08-01', '2026-08-02', '2026-08-03']);
    });
  });

  group('AdminMailSendResult.fromJson', () {
    test('parses the honest send outcome and per-recipient errors', () {
      final r = AdminMailSendResult.fromJson({
        'sent': 8,
        'failed': 1,
        'blocked': 1,
        'dispatchId': 'dispatch-1',
        'duplicate': false,
        'errors': [
          {'email': 'a@example.com', 'error': 'SMTP refused'},
        ],
      });

      expect(r.sent, 8);
      expect(r.failed, 1);
      expect(r.blocked, 1);
      expect(r.duplicate, false);
      expect(r.errors.single['error'], 'SMTP refused');
      expect(r.outcome, 'PARTIAL');
    });

    test('derives honest outcomes: SENT / FAILED / DUPLICATE / QUEUED', () {
      AdminMailSendResult from(Map<String, dynamic> json) =>
          AdminMailSendResult.fromJson(json);

      expect(from({'sent': 5, 'failed': 0}).outcome, 'SENT');
      expect(from({'sent': 0, 'failed': 3}).outcome, 'FAILED');
      expect(from({'sent': 2, 'duplicate': true}).outcome, 'DUPLICATE');
      expect(from({'sent': 0, 'failed': 0}).outcome, 'QUEUED');
    });
  });
}
