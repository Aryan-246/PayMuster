import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_announcements_screen.dart';
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

http.Response _campaignListResponse() => _encoded({
      'data': [
        {
          'id': 'c-1',
          'title': 'Payroll window',
          'body': 'Payroll closes Friday.',
          'type': 'INFORMATION',
          'audience': 'SYSTEM',
          'recipientCount': 2,
          'createdAt': '2026-08-18T12:00:00.000Z',
          'acknowledgementCount': 1,
        },
      ],
      'meta': {'total': 1, 'page': 1, 'totalPages': 1},
    }, 200);

http.Response _previewResponse() => _encoded({
      'data': {
        'audience': 'SYSTEM',
        'orgId': null,
        'recipientCount': 2,
        'sampleRecipients': [
          {
            'publicId': 'PM-USR-000001',
            'name': 'Asha Owner',
            'email': 'asha@example.com',
          },
        ],
      },
    }, 200);

http.Response _dispatchResponse() => _encoded({
      'data': {
        'campaignId': 'campaign-42',
        'audience': 'SYSTEM',
        'recipientCount': 2,
        'createdAt': '2026-08-17T12:00:00.000Z',
      },
    }, 201);

Widget _screenWith(http.Client client, {Widget? screen}) {
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
    child: MaterialApp(
      home: screen ?? const AdminAnnouncementsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
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

  testWidgets(
    'campaign history renders real rows without a null-model crash (regression for #7)',
    (tester) async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        return _campaignListResponse();
      });

      await tester.pumpWidget(_screenWith(client));
      await _settle(tester);

      expect(find.text('Payroll window'), findsOneWidget);
      expect(find.text('Payroll closes Friday.'), findsOneWidget);
      expect(find.text('1 of 2 acknowledged'), findsOneWidget);
      // The single authoritative compose entry point.
      expect(
        find.byKey(const Key('compose-announcement-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty campaign history shows the empty state without crashing (regression for #7)',
    (tester) async {
      final client = MockClient((request) async {
        return _encoded({
          'data': <Object>[],
          'meta': {'total': 0, 'page': 1, 'totalPages': 1},
        }, 200);
      });

      await tester.pumpWidget(_screenWith(client));
      await _settle(tester);

      expect(find.text('No announcements yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'composer previews the real recipient count, then dispatches after confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var previewCalls = 0;
      var dispatchCalls = 0;
      late Map<String, dynamic> postedBody;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/admin/announcements/preview')) {
          previewCalls += 1;
          return _previewResponse();
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/admin/announcements')) {
          dispatchCalls += 1;
          postedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _dispatchResponse();
        }
        return _campaignListResponse();
      });

      await tester.pumpWidget(
        _screenWith(client, screen: const AdminAnnouncementComposerScreen()),
      );
      await _settle(tester);

      // Buttons stay disabled until the form is valid.
      final preview = find.byKey(const Key('preview-announcement-button'));
      final dispatch = find.byKey(const Key('dispatch-announcement-button'));
      expect(tester.widget<OutlinedButton>(preview).onPressed, isNull);
      expect(tester.widget<FilledButton>(dispatch).onPressed, isNull);

      await _enterRequiredFields(tester);
      await tester.enterText(
        find.byKey(const Key('announcement-deep-link-field')),
        '/app/notices',
      );
      await tester.pump();

      // Dispatch without a preview first: it fetches the preview server-side
      // rather than dispatching blind.
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch);
      await tester.pumpAndSettle();

      expect(previewCalls, 1);
      expect(dispatchCalls, 0);
      expect(find.text('2 recipients will be notified'), findsOneWidget);
      expect(find.textContaining('Asha Owner'), findsOneWidget);

      // Now dispatch: confirmation shows the real count, then executes once.
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch);
      await tester.pumpAndSettle();

      expect(find.text('Dispatch announcement?'), findsOneWidget);
      expect(find.textContaining('will notify 2 recipients'), findsOneWidget);
      await tester.tap(find.text('Dispatch').last);
      await tester.pumpAndSettle();

      expect(dispatchCalls, 1);
      expect(previewCalls, 1);
      expect(find.text('Dispatched to 2 recipients'), findsOneWidget);
      expect(postedBody, {
        'title': 'Payroll window',
        'body': 'Payroll closes Friday.',
        'type': 'INFORMATION',
        'audience': 'SYSTEM',
        'deepLink': '/app/notices',
      });
      // Form cleared after a successful dispatch.
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('announcement-title-field')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'composer reports dispatch failure and preserves the pending form',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/admin/announcements/preview')) {
          return _previewResponse();
        }
        return _encoded({
          'error': {
            'code': 'FORBIDDEN',
            'message': 'The manage_system permission is required.',
          },
        }, 403);
      });

      await tester.pumpWidget(
        _screenWith(client, screen: const AdminAnnouncementComposerScreen()),
      );
      await _settle(tester);

      await _enterRequiredFields(tester);
      await tester.pump();

      final dispatch = find.byKey(const Key('dispatch-announcement-button'));
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch); // fetches preview first
      await tester.pumpAndSettle();
      await _scrollTo(tester, dispatch);
      await tester.tap(dispatch); // opens confirmation
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dispatch').last);
      await tester.pumpAndSettle();

      expect(
        find.text('The manage_system permission is required.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('announcement-title-field')),
            )
            .controller!
            .text,
        'Payroll window',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
