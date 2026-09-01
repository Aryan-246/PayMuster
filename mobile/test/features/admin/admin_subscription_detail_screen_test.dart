import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_site_detail_screen.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_subscription_detail_screen.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';

class _FakeAuthProvider implements AuthProviderBase {
  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> deleteAccount(String otp) async {}

  @override
  Future<User> fetchMe() => throw UnimplementedError();

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<void> requestDeleteAccountOtp(String password) async {}

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {}

  @override
  Future<User> signInWithApple() => throw UnimplementedError();

  @override
  Future<User> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<User> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<User> signUpWithEmail(String email, String password, String name) =>
      throw UnimplementedError();

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<void> verifyDeleteAccountOtp(String otp) async {}

  @override
  Future<void> verifyEmail(String email, String otp) async {}
}

http.Response _encoded(Map<String, dynamic> body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

const orgId = '22222222-2222-4222-8222-222222222222';

/// Detail payload for an organization with NO subscription record — the old
/// backend 404'd here, leaving admins with no way to manage access.
http.Response _noSubscriptionDetail() => _encoded({
      'data': {
        'subscription': null,
        'noSubscription': true,
        'provisionable': true,
        'org': {'id': orgId, 'publicId': 'PM-CMP-000001', 'name': 'Acme'},
        'owners': [
          {'firstName': 'Asha', 'lastName': 'Owner', 'publicId': 'PM-USR-1'},
        ],
        'ownerRequest': null,
        'history': <Object>[],
        'mailUsage': {'sentThisMonth': 3, 'periodEnd': '2026-10-01'},
      },
    }, 200);

http.Response _activeSubscriptionDetail({bool unlimited = false}) =>
    _encoded({
      'data': {
        'subscription': {
          'id': 'sub-1',
          'status': 'ACTIVE',
          'unlimitedAccess': unlimited,
          'currentPeriodEnd': '2126-01-01T00:00:00.000Z',
          'plan': {'code': 'FREE', 'name': 'Free', 'amountMinor': 0},
          'entitlements': <Object>[],
          'invoices': <Object>[],
          'paymentEvents': <Object>[],
        },
        'noSubscription': false,
        'provisionable': false,
        'org': {'id': orgId, 'publicId': 'PM-CMP-000001', 'name': 'Acme'},
        'owners': <Object>[],
        'history': <Object>[],
        'mailUsage': {'sentThisMonth': 3, 'periodEnd': '2026-10-01'},
      },
    }, 200);

Widget _screenWith(http.Client client, Widget screen) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authProvider.overrideWithValue(_FakeAuthProvider()),
      adminApiClientProvider.overrideWith((ref) {
        final api = AdminApiClient(ref, client: client);
        ref.onDispose(api.close);
        return api;
      }),
    ],
    child: MaterialApp(home: screen),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets(
    'organizations without a subscription show an actionable empty state, not a dead end (regression for #4/#5)',
    (tester) async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/admin/subscriptions/orgs/$orgId'));
        return _noSubscriptionDetail();
      });

      await tester.pumpWidget(
        _screenWith(
          client,
          AdminSubscriptionDetailScreen(orgId: orgId),
        ),
      );
      await _settle(tester);

      expect(find.text('Acme'), findsOneWidget);
      expect(find.textContaining('no subscription record yet'), findsOneWidget);
      expect(find.text('No active plan'), findsOneWidget);
      // Grant Unlimited stays available — it provisions through the service.
      expect(find.text('Grant Unlimited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grant unlimited executes after confirmation and refreshes the badge',
    (tester) async {
      var grantCalls = 0;
      var detailCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path
                .endsWith('/admin/subscription/orgs/$orgId/unlimited')) {
          grantCalls += 1;
          return _encoded({'data': {'id': 'sub-1', 'unlimitedAccess': true}}, 200);
        }
        detailCalls += 1;
        // First load: standard subscription. After the grant: unlimited.
        return _activeSubscriptionDetail(unlimited: detailCalls > 1);
      });

      await tester.pumpWidget(
        _screenWith(
          client,
          AdminSubscriptionDetailScreen(orgId: orgId),
        ),
      );
      await _settle(tester);

      expect(find.text('STANDARD'), findsOneWidget);

      await tester.tap(find.text('Grant Unlimited'));
      await tester.pumpAndSettle();
      // Confirmation explains the consequence before anything executes.
      expect(find.text('Grant unlimited access?'), findsOneWidget);
      expect(grantCalls, 0);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(grantCalls, 1);
      expect(find.text('Unlimited access granted. Owners notified and audit recorded.'),
          findsOneWidget);
      expect(find.text('GRANTED'), findsOneWidget);
      expect(find.text('STANDARD'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'site detail renders workers, counts and coordinates (regression for #8)',
    (tester) async {
      const siteId = '33333333-3333-4333-8333-333333333333';
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/admin/sites/$siteId'));
        return _encoded({
          'data': {
            'id': siteId,
            'publicId': 'PM-SIT-000001',
            'name': 'Riverside Tower',
            'address': '12 River Road',
            'latitude': 19.076,
            'longitude': 72.8777,
            'status': 'ACTIVE',
            'createdAt': '2026-01-15T08:00:00.000Z',
            'updatedAt': '2026-08-01T08:00:00.000Z',
            'org': {
              'id': orgId,
              'publicId': 'PM-CMP-000001',
              'name': 'Acme',
            },
            'siteAssignments': [
              {
                'id': 'a-1',
                'publicId': 'PM-ASG-000001',
                'assignedAt': '2026-02-01T08:00:00.000Z',
                'staff': {
                  'id': '44444444-4444-4444-8444-444444444444',
                  'publicId': 'PM-USR-000002',
                  'firstName': 'Ravi',
                  'lastName': 'Kumar',
                },
              },
            ],
            'siteMembers': <Object>[],
            '_count': {
              'siteAssignments': 1,
              'attendanceRecords': 27,
              'siteMembers': 0,
            },
          },
        }, 200);
      });

      await tester.pumpWidget(
        _screenWith(client, AdminSiteDetailScreen(siteId: siteId)),
      );
      await _settle(tester);

      expect(find.text('Riverside Tower'), findsOneWidget);
      expect(find.textContaining('Acme'), findsOneWidget);
      expect(find.text('19.076000, 72.877700'), findsOneWidget);
      expect(find.textContaining('Ravi Kumar'), findsOneWidget);
      expect(find.textContaining('27'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
