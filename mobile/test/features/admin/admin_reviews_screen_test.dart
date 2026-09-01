import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_reviews_screen.dart';
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

http.Response _ok(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
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
    child: const MaterialApp(home: AdminReviewsScreen()),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets('renders the summary and review rows from real API data', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/reviews/summary')) {
        return _ok({
          'data': {
            'total': 4,
            'average': 4.3,
            'distribution': {'4': 3, '5': 1},
            'pendingCount': 1,
            'publishedCount': 3,
            'hiddenCount': 0,
            'flaggedCount': 0,
          },
        });
      }
      return _ok({
        'data': [
          {
            'id': 'rev-1',
            'publicId': 'PM-REV-000001',
            'rating': 4,
            'text': 'Payroll has been reliable.',
            'status': 'PENDING',
            'createdAt': '2026-08-20T10:00:00.000Z',
            'user': {
              'publicId': 'PM-USR-000004',
              'firstName': 'Ravi',
              'lastName': 'K',
              'email': 'ravi@example.com',
              'role': 'OWNER',
            },
            'org': {'name': 'Acme Construction', 'publicId': 'PM-CMP-000001'},
          },
        ],
        'meta': {'total': 1, 'page': 1, 'totalPages': 1},
      });
    });

    await tester.pumpWidget(_screenWith(client));
    await tester.pumpAndSettle();

    expect(find.text('Payroll has been reliable.'), findsOneWidget);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.textContaining('Ravi K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an error state with retry when the reviews call fails', (
    tester,
  ) async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'FORBIDDEN',
            'message': 'The manage_system permission is required.',
          },
        }),
        403,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(_screenWith(client));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The manage_system permission is required.'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
