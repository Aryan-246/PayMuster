import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/data/admin_models.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';

class _FakeAuthProvider implements AuthProviderBase {
  String? accessToken = 'access-token';
  bool refreshResult = false;
  int refreshCalls = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<bool> refreshAccessToken() async {
    refreshCalls += 1;
    if (refreshResult) accessToken = 'refreshed-token';
    return refreshResult;
  }

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

Provider<AdminApiClient> _adminProviderFor(http.Client client) {
  return Provider<AdminApiClient>((ref) {
    final api = AdminApiClient(ref, client: client);
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

Map<String, dynamic> _campaign({String audience = 'SYSTEM', String? orgId}) => {
  'campaignId': 'campaign-1',
  'audience': audience,
  'orgId': ?orgId,
  'recipientCount': 3,
  'createdAt': '2026-08-17T12:00:00.000Z',
};

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  test(
    'dispatches a system announcement with authenticated JSON and no org id',
    () async {
      final auth = _FakeAuthProvider();
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({'data': _campaign()}, 201);
      });
      final provider = _adminProviderFor(client);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(provider)
          .dispatchAnnouncement(
            const AnnouncementDispatchRequest(
              title: '  Payroll window  ',
              type: 'INFORMATION',
              body: '  Payroll closes Friday.  ',
              audience: 'SYSTEM',
              orgId: '   ',
              deepLink: '   ',
            ),
          );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/admin/announcements');
      expect(capturedRequest.headers['authorization'], 'Bearer access-token');
      expect(jsonDecode(capturedRequest.body), {
        'title': 'Payroll window',
        'body': 'Payroll closes Friday.',
        'type': 'INFORMATION',
        'audience': 'SYSTEM',
      });
      expect(result.campaignId, 'campaign-1');
      expect(result.recipientCount, 3);
      expect(result.orgId, isNull);
    },
  );

  test(
    'includes organization context and internal link for organization dispatch',
    () async {
      final auth = _FakeAuthProvider();
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'data': _campaign(
            audience: 'ORGANIZATION',
            orgId: '11111111-1111-1111-1111-111111111111',
          ),
        }, 201);
      });
      final provider = _adminProviderFor(client);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      await container
          .read(provider)
          .dispatchAnnouncement(
            const AnnouncementDispatchRequest(
              title: 'Policy update',
              type: 'INFORMATION',
              body: 'Review the updated policy.',
              audience: 'ORGANIZATION',
              orgId: ' 11111111-1111-1111-1111-111111111111 ',
              deepLink: ' /app/notices ',
            ),
          );

      expect(jsonDecode(capturedRequest.body), {
        'title': 'Policy update',
        'body': 'Review the updated policy.',
        'type': 'INFORMATION',
        'audience': 'ORGANIZATION',
        'orgId': '11111111-1111-1111-1111-111111111111',
        'deepLink': '/app/notices',
      });
    },
  );

  test(
    'refreshes once and retries once after unauthorized dispatch response',
    () async {
      final auth = _FakeAuthProvider()..refreshResult = true;
      final authorizationHeaders = <String?>[];
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount += 1;
        authorizationHeaders.add(request.headers['authorization']);
        if (requestCount == 1) {
          return _jsonResponse({'message': 'Unauthorized'}, 401);
        }
        return _jsonResponse({'data': _campaign()}, 201);
      });
      final provider = _adminProviderFor(client);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(provider)
          .dispatchAnnouncement(
            const AnnouncementDispatchRequest(
              title: 'Title',
              type: 'INFORMATION',
              body: 'Body',
              audience: 'SYSTEM',
            ),
          );

      expect(result.campaignId, 'campaign-1');
      expect(requestCount, 2);
      expect(auth.refreshCalls, 1);
      expect(authorizationHeaders, [
        'Bearer access-token',
        'Bearer refreshed-token',
      ]);
    },
  );

  test(
    'surfaces backend dispatch errors without converting them to success',
    () async {
      final auth = _FakeAuthProvider();
      final client = MockClient(
        (_) async => _jsonResponse({
          'error': {
            'code': 'FORBIDDEN',
            'message': 'The manage_system permission is required.',
          },
        }, 403),
      );
      final provider = _adminProviderFor(client);
      final container = ProviderContainer(
        overrides: [authProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(provider)
            .dispatchAnnouncement(
              const AnnouncementDispatchRequest(
                title: 'Title',
                type: 'INFORMATION',
                body: 'Body',
                audience: 'SYSTEM',
              ),
            ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('The manage_system permission is required.'),
          ),
        ),
      );
    },
  );

  test('rejects malformed campaign evidence', () async {
    final auth = _FakeAuthProvider();
    final client = MockClient(
      (_) async => _jsonResponse({
        'data': {
          'campaignId': 'campaign-1',
          'audience': 'SYSTEM',
          'recipientCount': '3',
          'createdAt': 'not-a-date',
        },
      }, 201),
    );
    final provider = _adminProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(provider)
          .dispatchAnnouncement(
            const AnnouncementDispatchRequest(
              title: 'Title',
              type: 'INFORMATION',
              body: 'Body',
              audience: 'SYSTEM',
            ),
          ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('invalid campaign data'),
        ),
      ),
    );
  });
}
