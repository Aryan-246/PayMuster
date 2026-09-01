import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/features/reviews/data/reviews_api.dart';

const _tenantUser = User(
  id: 'user-1',
  email: 'owner@example.com',
  role: UserRole.owner,
  organizationId: 'org-1',
);

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
  Future<User?> getCurrentUser() async => _tenantUser;

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

ProviderContainer _containerFor(http.Client client) {
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWithValue(_FakeAuthProvider()),
      _clientProviderFor(client),
    ],
  );
  return container;
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

  test('submit posts the rating and text to /api/v1/reviews', () async {
    late http.Request captured;
    final httpClient = MockClient((request) async {
      captured = request;
      return _jsonResponse({
        'data': {
          'id': 'rev-1',
          'publicId': 'PM-REV-000001',
          'rating': 5,
          'text': 'Great company overall.',
          'status': 'PENDING',
          'createdAt': '2026-09-01T10:00:00.000Z',
        },
      }, 201);
    });

    final container = _containerFor(httpClient);
    addTearDown(container.dispose);

    final review = await ReviewsApi(
      container.read(_clientProviderFor(httpClient)),
    ).submit(rating: 5, text: 'Great company overall.');

    expect(review.status, 'PENDING');
    expect(review.publicId, 'PM-REV-000001');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/reviews');
    expect(
      jsonDecode(captured.body),
      {'rating': 5, 'text': 'Great company overall.'},
    );
  });

  test('listMine parses the user’s own reviews with moderation state', () async {
    final httpClient = MockClient((_) async {
      return _jsonResponse({
        'data': [
          {
            'id': 'rev-1',
            'publicId': 'PM-REV-000001',
            'rating': 4,
            'text': 'Solid payroll experience.',
            'status': 'PUBLISHED',
            'adminResponse': 'Thank you!',
            'moderatedAt': '2026-08-16T10:00:00.000Z',
            'createdAt': '2026-08-15T10:00:00.000Z',
          },
        ],
      }, 200);
    });

    final container = _containerFor(httpClient);
    addTearDown(container.dispose);

    final mine = await ReviewsApi(
      container.read(_clientProviderFor(httpClient)),
    ).listMine();

    expect(mine.length, 1);
    expect(mine.single.status, 'PUBLISHED');
    expect(mine.single.adminResponse, 'Thank you!');
  });

  test('submit surfaces the server REVIEW_DUPLICATE conflict, never a fake success', () async {
    final httpClient = MockClient((_) async {
      return _jsonResponse({
        'error': {
          'code': 'REVIEW_DUPLICATE',
          'message': 'You have already reviewed this company. Your review is published.',
        },
      }, 409);
    });

    final container = _containerFor(httpClient);
    addTearDown(container.dispose);

    await expectLater(
      ReviewsApi(
        container.read(_clientProviderFor(httpClient)),
      ).submit(rating: 4, text: 'Trying to review again.'),
      throwsA(
        isA<TenantApiException>()
            .having((e) => e.code, 'code', 'REVIEW_DUPLICATE')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });
}
