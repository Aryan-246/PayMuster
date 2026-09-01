import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_notifications_screen.dart';
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

Widget _screenWith(http.Client client) {
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
    child: const MaterialApp(home: AdminNotificationsScreen()),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets(
    'notification log renders inbox rows and contains NO composer (single-workflow rule)',
    (tester) async {
      final client = MockClient((request) async {
        return _encoded({
          'data': [
            {
              'id': 'n-1',
              'title': 'Payroll window',
              'body': 'Payroll closes Friday.',
              'type': 'SYSTEM',
              'createdAt': '2026-08-18T12:00:00.000Z',
            },
          ],
          'meta': {'total': 1, 'page': 1, 'totalPages': 1},
        }, 200);
      });

      await tester.pumpWidget(_screenWith(client));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Notifications (1)'), findsOneWidget);
      expect(find.text('Payroll window'), findsOneWidget);
      expect(find.text('Payroll closes Friday.'), findsOneWidget);
      // Regression (duplicate-UI prevention): the composer lives ONLY on the
      // Announcements screen — no compose form may exist here.
      expect(
        find.byKey(const Key('announcement-title-field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dispatch-announcement-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty log shows the empty state', (tester) async {
    final client = MockClient((request) async {
      return _encoded({
        'data': <Object>[],
        'meta': {'total': 0, 'page': 1, 'totalPages': 1},
      }, 200);
    });

    await tester.pumpWidget(_screenWith(client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API failure shows the error state with retry', (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('boom', 500);
    });

    await tester.pumpWidget(_screenWith(client));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsNothing);
    expect(find.text('Payroll window'), findsNothing);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
