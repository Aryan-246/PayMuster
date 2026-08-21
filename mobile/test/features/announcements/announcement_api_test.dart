import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/announcements/data/announcement_api.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';

const _unaffiliatedUser = User(
  id: 'user-1',
  email: 'worker@example.com',
  role: UserRole.staff,
);

class _FakeAuthProvider implements AuthProviderBase {
  String? accessToken = 'access-token';
  bool refreshResult = false;
  int refreshCalls = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<User?> getCurrentUser() async => _unaffiliatedUser;

  @override
  Future<User> fetchMe() async => _unaffiliatedUser;

  @override
  Future<bool> refreshAccessToken() async {
    refreshCalls += 1;
    if (refreshResult) accessToken = 'refreshed-token';
    return refreshResult;
  }

  @override
  Future<void> deleteAccount(String otp) async {}

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

Provider<AnnouncementApiClient> _clientProviderFor(http.Client client) {
  return Provider<AnnouncementApiClient>((ref) {
    final api = AnnouncementApiClient(ref, client: client);
    ref.onDispose(api.close);
    return api;
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  test(
    'lists persisted notices without requiring or sending tenant context',
    () async {
      final auth = _FakeAuthProvider();
      late http.Request capturedRequest;
      final httpClient = MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'data': [
            {
              'id': 'notice-1',
              'title': 'Payroll window',
              'body': 'Payroll closes Friday.',
              'deepLink': '/app/payroll',
              'readAt': null,
              'createdAt': '2026-08-17T12:00:00.000Z',
            },
          ],
          'meta': {'total': 1, 'unread': 1, 'page': 1, 'totalPages': 1},
        }, 200);
      });
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final page = await container
          .read(_clientProviderFor(httpClient))
          .listAnnouncements(limit: 100);

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/v1/announcements');
      expect(capturedRequest.url.queryParameters, {
        'page': '1',
        'limit': '100',
      });
      expect(capturedRequest.headers['authorization'], 'Bearer access-token');
      expect(capturedRequest.headers, isNot(contains('x-company-id')));
      expect(page.total, 1);
      expect(page.unread, 1);
      expect(page.announcements.single.deepLink, '/app/payroll');
      expect(page.announcements.single.isAcknowledged, isFalse);
    },
  );

  test('preserves typed backend errors', () async {
    final auth = _FakeAuthProvider();
    final httpClient = MockClient(
      (_) async => _jsonResponse({
        'error': {
          'code': 'ANNOUNCEMENT_ACCESS_DENIED',
          'message': 'Announcements are unavailable for this account.',
        },
      }, 403),
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(_clientProviderFor(httpClient)).listAnnouncements(),
      throwsA(
        isA<AnnouncementApiException>()
            .having((error) => error.code, 'code', 'ANNOUNCEMENT_ACCESS_DENIED')
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              'Announcements are unavailable for this account.',
            ),
      ),
    );
  });

  test(
    'refreshes exactly once and retries exactly once after unauthorized',
    () async {
      final auth = _FakeAuthProvider()..refreshResult = true;
      final authorizationHeaders = <String?>[];
      var requestCount = 0;
      final httpClient = MockClient((request) async {
        requestCount += 1;
        authorizationHeaders.add(request.headers['authorization']);
        return _jsonResponse({
          'error': {'code': 'UNAUTHORIZED', 'message': 'Unauthorized'},
        }, 401);
      });
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(_clientProviderFor(httpClient)).listAnnouncements(),
        throwsA(
          isA<AnnouncementApiException>()
              .having((error) => error.code, 'code', 'UNAUTHORIZED')
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );

      expect(requestCount, 2);
      expect(auth.refreshCalls, 1);
      expect(authorizationHeaders, [
        'Bearer access-token',
        'Bearer refreshed-token',
      ]);
    },
  );

  test(
    'acknowledges the recipient notice and parses idempotency evidence',
    () async {
      final auth = _FakeAuthProvider();
      late http.Request capturedRequest;
      final httpClient = MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'data': {
            'id': '550e8400-e29b-41d4-a716-446655440000',
            'acknowledgedAt': '2026-08-17T12:30:00.000Z',
            'changed': true,
          },
        }, 200);
      });
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final acknowledgement = await container
          .read(_clientProviderFor(httpClient))
          .acknowledge('550e8400-e29b-41d4-a716-446655440000');

      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url.path,
        '/api/v1/announcements/550e8400-e29b-41d4-a716-446655440000/acknowledge',
      );
      expect(jsonDecode(capturedRequest.body), isEmpty);
      expect(capturedRequest.headers, isNot(contains('x-company-id')));
      expect(acknowledgement.changed, isTrue);
      expect(acknowledgement.acknowledgedAt.isUtc, isTrue);
    },
  );

  test('rejects malformed persistent notice payloads', () async {
    final auth = _FakeAuthProvider();
    final httpClient = MockClient(
      (_) async => _jsonResponse({
        'data': [
          {
            'id': 'notice-1',
            'title': 'Unsafe link',
            'body': 'This payload must fail closed.',
            'deepLink': 'https://example.com',
            'readAt': null,
            'createdAt': '2026-08-17T12:00:00.000Z',
          },
        ],
        'meta': {'total': 1, 'unread': 1, 'page': 1, 'totalPages': 1},
      }, 200),
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(_clientProviderFor(httpClient)).listAnnouncements(),
      throwsA(
        isA<AnnouncementApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('parses only announcement invalidation events from the stream', () async {
    final auth = _FakeAuthProvider();
    late http.Request capturedRequest;
    final httpClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        'event: ready\n'
        'data: {"connectedAt":"2026-08-17T12:00:00.000Z"}\n\n'
        ': heartbeat\n\n'
        'event: announcements-invalidated\n'
        'data: {"reason":"dispatch","occurredAt":"2026-08-17T12:01:00.000Z"}\n\n'
        ': end\n\n',
        200,
        headers: const {'content-type': 'text/event-stream'},
      );
    });
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    final invalidations = await container
        .read(_clientProviderFor(httpClient))
        .watchInvalidations()
        .toList();

    expect(capturedRequest.url.path, '/api/v1/announcements/stream');
    expect(capturedRequest.headers['authorization'], 'Bearer access-token');
    expect(capturedRequest.headers, isNot(contains('x-company-id')));
    expect(invalidations, hasLength(1));
    expect(invalidations.single.reason, 'dispatch');
    expect(
      invalidations.single.occurredAt,
      DateTime.parse('2026-08-17T12:01:00.000Z'),
    );
  });
}
