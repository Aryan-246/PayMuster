import 'dart:async';
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

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response _emptyLogResponse({int total = 0}) => _jsonResponse({
  'data': <Object>[],
  'meta': {'total': total, 'page': 1, 'totalPages': 1},
}, 200);

http.Response _logResponse({
  required String title,
  required String body,
  int total = 1,
}) => _jsonResponse({
  'data': [
    {
      'id': '$title-id',
      'title': title,
      'body': body,
      'type': 'SYSTEM',
      'createdAt': '2026-08-18T12:00:00.000Z',
    },
  ],
  'meta': {'total': total, 'page': 1, 'totalPages': 1},
}, 200);

http.Response _dispatchResponse() => _jsonResponse({
  'data': {
    'campaignId': 'campaign-42',
    'audience': 'SYSTEM',
    'recipientCount': 2,
    'createdAt': '2026-08-17T12:00:00.000Z',
  },
}, 201);

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

Future<void> _settleInitialLog(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _enterRequiredFields(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('announcement-title-field')),
    'Payroll window',
  );
  await tester.enterText(
    find.byKey(const Key('announcement-body-field')),
    'Payroll closes Friday.',
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets('validates dispatch fields and organization-specific context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var postCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _emptyLogResponse();
      postCalls += 1;
      return _dispatchResponse();
    });

    await tester.pumpWidget(_screenWith(client));
    await _settleInitialLog(tester);

    final dispatch = find.byKey(const Key('dispatch-announcement-button'));
    await _scrollTo(tester, dispatch);
    await tester.tap(dispatch);
    await tester.pump();

    expect(find.text('Title must be at least 2 characters.'), findsOneWidget);
    expect(find.text('Message must be at least 2 characters.'), findsOneWidget);
    expect(postCalls, 0);

    final audience = find.byKey(const Key('announcement-audience-control'));
    await _scrollTo(tester, audience);
    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement-org-id-field')), findsOneWidget);
    await _enterRequiredFields(tester);
    await tester.enterText(
      find.byKey(const Key('announcement-org-id-field')),
      'not-a-uuid',
    );
    await tester.enterText(
      find.byKey(const Key('announcement-deep-link-field')),
      'https://example.com/notices',
    );
    await _scrollTo(tester, dispatch);
    await tester.tap(dispatch);
    await tester.pump();

    expect(find.text('Enter a valid organization UUID.'), findsOneWidget);
    expect(find.text('Enter an internal /app/ path.'), findsOneWidget);
    expect(postCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'blocks duplicate dispatch and refreshes durable log on success',
    (tester) async {
      final dispatchGate = Completer<http.Response>();
      var getCalls = 0;
      var postCalls = 0;
      late Map<String, dynamic> postedBody;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          getCalls += 1;
          return _emptyLogResponse();
        }
        postCalls += 1;
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return dispatchGate.future;
      });

      await tester.pumpWidget(_screenWith(client));
      await _settleInitialLog(tester);
      await _enterRequiredFields(tester);
      await tester.enterText(
        find.byKey(const Key('announcement-deep-link-field')),
        '/app/notices',
      );

      final dispatch = find.byKey(const Key('dispatch-announcement-button'));
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch);
      await tester.pump();

      expect(postCalls, 1);
      expect(find.text('Dispatching'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(dispatch).onPressed, isNull);
      await tester.tap(dispatch);
      await tester.pump();
      expect(postCalls, 1);

      dispatchGate.complete(_dispatchResponse());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Announcement dispatched to 2 recipients. Campaign campaign-42.',
        ),
        findsOneWidget,
      );
      expect(getCalls, 2);
      expect(postedBody, {
        'title': 'Payroll window',
        'body': 'Payroll closes Friday.',
        'type': 'INFORMATION',
        'audience': 'SYSTEM',
        'deepLink': '/app/notices',
      });
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('announcement-title-field')),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'ignores a stale manual log refresh after dispatch refreshes the durable log',
    (tester) async {
      final staleRefresh = Completer<http.Response>();
      var getCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          getCalls += 1;
          if (getCalls == 1) return _emptyLogResponse();
          if (getCalls == 2) return staleRefresh.future;
          return _logResponse(
            title: 'New announcement',
            body: 'The durable campaign log is current.',
          );
        }
        return _dispatchResponse();
      });

      await tester.pumpWidget(_screenWith(client));
      await _settleInitialLog(tester);
      await _enterRequiredFields(tester);
      await tester.enterText(
        find.byKey(const Key('announcement-deep-link-field')),
        '/app/notices',
      );

      await tester.tap(find.byTooltip('Refresh notification log'));
      await tester.pump();
      expect(getCalls, 2);

      final dispatch = find.byKey(const Key('dispatch-announcement-button'));
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch);
      await tester.pumpAndSettle();

      expect(getCalls, 3);
      await _scrollTo(tester, find.text('New announcement'));
      expect(find.text('New announcement'), findsOneWidget);
      expect(find.text('The durable campaign log is current.'), findsOneWidget);
      expect(find.text('Old announcement'), findsNothing);

      staleRefresh.complete(
        _logResponse(
          title: 'Old announcement',
          body: 'This response was started earlier and is stale.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New announcement'), findsOneWidget);
      expect(find.text('The durable campaign log is current.'), findsOneWidget);
      expect(find.text('Old announcement'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reports dispatch failure and preserves the pending form', (
    tester,
  ) async {
    var getCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        getCalls += 1;
        return _emptyLogResponse();
      }
      return _jsonResponse({
        'error': {
          'code': 'FORBIDDEN',
          'message': 'The manage_system permission is required.',
        },
      }, 403);
    });

    await tester.pumpWidget(_screenWith(client));
    await _settleInitialLog(tester);
    await _enterRequiredFields(tester);

    final dispatch = find.byKey(const Key('dispatch-announcement-button'));
    await _scrollTo(tester, dispatch);
    tester.widget<ElevatedButton>(dispatch).onPressed!();
    await tester.pumpAndSettle();

    expect(
      find.text('The manage_system permission is required.'),
      findsOneWidget,
    );
    expect(getCalls, 1);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('announcement-title-field')),
          )
          .controller!
          .text,
      'Payroll window',
    );
    expect(find.text('Dispatch'), findsOneWidget);
  });
}
