import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';

const _tenantUser = User(
  id: 'user-1',
  email: 'owner@example.com',
  role: UserRole.owner,
  organizationId: 'org-1',
);

class _FakeAuthProvider implements AuthProviderBase {
  String? accessToken = 'access-token';
  User? currentUser = _tenantUser;
  User fetchedUser = _tenantUser;
  bool refreshResult = false;
  int refreshCalls = 0;
  int fetchMeCalls = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<User?> getCurrentUser() async => currentUser;

  @override
  Future<User> fetchMe() async {
    fetchMeCalls += 1;
    currentUser = fetchedUser;
    return fetchedUser;
  }

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

Provider<TenantApiClient> _clientProviderFor(http.Client client) {
  return Provider<TenantApiClient>((ref) {
    final api = TenantApiClient(ref, client: client);
    ref.onDispose(api.close);
    return api;
  });
}

http.Response _jsonResponse(
  Map<String, dynamic> body,
  int statusCode, {
  Map<String, String> headers = const {},
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    },
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  test('adds tenant context and omits null or blank query values', () async {
    final auth = _FakeAuthProvider();
    late http.Request capturedRequest;
    final httpClient = MockClient((request) async {
      capturedRequest = request;
      return _jsonResponse({'data': <dynamic>[]}, 200);
    });
    final clientProvider = _clientProviderFor(httpClient);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    final data = await container
        .read(clientProvider)
        .get(
          '/payroll',
          query: {'payCycleId': 'cycle-1', 'siteId': null, 'status': ''},
        );

    expect(data, isEmpty);
    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/v1/payroll');
    expect(capturedRequest.url.queryParameters, {'payCycleId': 'cycle-1'});
    expect(capturedRequest.headers['authorization'], 'Bearer access-token');
    expect(capturedRequest.headers['x-company-id'], 'org-1');
    expect(auth.fetchMeCalls, 0);
  });

  test('preserves typed backend error details', () async {
    final auth = _FakeAuthProvider();
    final httpClient = MockClient(
      (_) async => _jsonResponse(
        {
          'error': {
            'code': 'PAYROLL_ACCESS_DENIED',
            'message': 'Payroll access is not allowed for this role.',
          },
        },
        403,
        headers: {'x-request-id': 'request-403'},
      ),
    );
    final clientProvider = _clientProviderFor(httpClient);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(clientProvider).get('/payroll'),
      throwsA(
        isA<TenantApiException>()
            .having((error) => error.code, 'code', 'PAYROLL_ACCESS_DENIED')
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.requestId, 'requestId', 'request-403')
            .having(
              (error) => error.message,
              'message',
              'Payroll access is not allowed for this role.',
            ),
      ),
    );
  });

  test('refreshes once and retries once after unauthorized response', () async {
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
    final clientProvider = _clientProviderFor(httpClient);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(clientProvider).get('/payroll'),
      throwsA(
        isA<TenantApiException>()
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
  });
}
