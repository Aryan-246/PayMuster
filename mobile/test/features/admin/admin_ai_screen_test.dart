import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_ai_screen.dart';
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

http.Response _confirmationResult() => _encoded({
      'data': {
        'message':
            'Confirmation required. Reply with the token to execute GRANT_UNLIMITED on Acme Construction.',
        'intent': 'CONFIRMATION_REQUIRED',
        'provider': 'gemini',
        'model': 'gemini-2.5-flash',
        'generatedAt': '2026-09-01T10:00:00.000Z',
        'toolCalls': [
          {
            'name': 'grant_unlimited_access',
            'args': {'orgRef': 'Acme Construction'},
            'summary': 'Resolved Acme Construction.',
          },
        ],
        'entities': [
          {
            'type': 'org',
            'id': '22222222-2222-4222-8222-222222222222',
            'publicId': 'PM-CMP-000001',
            'name': 'Acme Construction',
            'subtitle': null,
            'route': '/admin/subscriptions/22222222-2222-4222-8222-222222222222',
          },
        ],
        'metrics': null,
        'contextUsed': null,
        'confirmation': {
          'operation': 'GRANT_UNLIMITED',
          'target': {
            'type': 'org',
            'id': '22222222-2222-4222-8222-222222222222',
            'publicId': 'PM-CMP-000001',
            'name': 'Acme Construction',
            'subtitle': null,
          },
          'currentState': {'subscription': null},
          'consequences':
              'Grant unlimited access to Acme Construction: the organization bypasses all plan limits immediately.',
          'expiresAt': '2999-01-01T00:00:00.000Z',
          'token': 'aaaaaaaa-bbbb-4bbb-8bbb-cccccccccccc',
        },
        'degraded': false,
        'durationMs': 1200,
      },
    }, 200);

http.Response _executedResult() => _encoded({
      'data': {
        'message':
            'Executed GRANT_UNLIMITED on Acme Construction — unlimited access is now GRANTED.',
        'intent': 'ACTION_EXECUTED',
        'provider': 'gemini',
        'model': 'gemini-2.5-flash',
        'generatedAt': '2026-09-01T10:00:05.000Z',
        'toolCalls': <Object>[],
        'entities': <Object>[],
        'metrics': null,
        'contextUsed': null,
        'executedAction': {
          'operation': 'GRANT_UNLIMITED',
          'targetId': '22222222-2222-4222-8222-222222222222',
          'targetName': 'Acme Construction',
          'status': 'SUCCESS',
          'result': {'id': 'sub-1', 'unlimitedAccess': true},
        },
        'degraded': false,
        'durationMs': 800,
      },
    }, 200);

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
    child: const MaterialApp(home: AdminAiScreen()),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets(
    'destructive proposal shows the confirmation card and executes ONLY after approval',
    (tester) async {
      var chatCalls = 0;
      var confirmationsSent = 0;
      late Map<String, dynamic> lastBody;
      final client = MockClient((request) async {
        chatCalls += 1;
        lastBody = jsonDecode(request.body) as Map<String, dynamic>;
        if (lastBody.containsKey('confirmationToken')) {
          confirmationsSent += 1;
          expect(lastBody['confirmationToken'], 'aaaaaaaa-bbbb-4bbb-8bbb-cccccccccccc');
          return _executedResult();
        }
        return _confirmationResult();
      });

      await tester.pumpWidget(_screenWith(client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Grant unlimited access to Acme Construction',
      );
      await tester.tap(find.text('Ask assistant'));
      await tester.pumpAndSettle();

      // Proposal: nothing executed, confirmation card visible.
      expect(chatCalls, 1);
      expect(confirmationsSent, 0);
      expect(find.text('CONFIRMATION_REQUIRED'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Action proposed — approval required'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Action proposed — approval required'), findsOneWidget);
      expect(find.textContaining('GRANT_UNLIMITED → Acme Construction'),
          findsOneWidget);

      // Approve: token sent, executed result rendered.
      await tester.tap(find.byKey(const Key('ai-approve-action-button')));
      await tester.pumpAndSettle();

      expect(confirmationsSent, 1);
      expect(find.text('ACTION_EXECUTED'), findsOneWidget);
      expect(find.textContaining('Executed GRANT_UNLIMITED on Acme Construction'),
          findsOneWidget);
      // The confirmation card is gone — the token is single-use.
      expect(find.text('Action proposed — approval required'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assistant answers render with intent badge and open the detail screen on tap',
    (tester) async {
      final client = MockClient((request) async {
        return _encoded({
          'data': {
            'message': 'There are 12 users on the platform.',
            'intent': 'ANSWER',
            'provider': 'gemini',
            'model': 'gemini-2.5-flash',
            'generatedAt': '2026-09-01T10:00:00.000Z',
            'toolCalls': [
              {'name': 'platform_stats', 'args': {}, 'summary': '12 users.'},
            ],
            'entities': <Object>[],
            'metrics': {'users': 12},
            'contextUsed': null,
            'degraded': false,
            'durationMs': 1500,
          },
        }, 200);
      });

      await tester.pumpWidget(_screenWith(client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'How many users are on the platform?',
      );
      await tester.tap(find.text('Ask assistant'));
      await tester.pumpAndSettle();

      expect(find.text('ANSWER'), findsOneWidget);
      expect(find.text('There are 12 users on the platform.'), findsOneWidget);

      await tester.tap(find.text('Assistant response'));
      await tester.pumpAndSettle();

      // Detail screen shows prompt, answer, tools and metrics.
      expect(find.text('AI analysis detail'), findsOneWidget);
      expect(find.text('How many users are on the platform?'), findsOneWidget);
      expect(find.text('platform_stats'), findsOneWidget);
      expect(find.text('Relevant metrics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
