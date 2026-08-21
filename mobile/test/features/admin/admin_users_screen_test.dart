import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_users_screen.dart';
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

http.Response _usersResponse(String id, String name) {
  return http.Response(
    jsonEncode({
      'data': [
        {
          'id': id,
          'publicId': 'PM-$id',
          'email': '$id@example.com',
          'firstName': name,
          'lastName': 'User',
          'role': 'STAFF',
          'status': 'VERIFIED',
          'isDisabled': false,
          'emailVerified': true,
        },
      ],
      'meta': {'total': 1, 'page': 1, 'totalPages': 1},
    }),
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
    child: const MaterialApp(home: AdminUsersScreen()),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets('ignores a late users response after a newer refresh', (
    tester,
  ) async {
    final firstResponse = Completer<http.Response>();
    final secondResponse = Completer<http.Response>();
    var getCalls = 0;
    final client = MockClient((request) async {
      getCalls += 1;
      if (getCalls == 1) return firstResponse.future;
      return secondResponse.future;
    });

    await tester.pumpWidget(_screenWith(client));
    await tester.pump();
    expect(getCalls, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(getCalls, 2);

    secondResponse.complete(_usersResponse('new-user', 'New'));
    await tester.pumpAndSettle();
    expect(find.text('New User'), findsOneWidget);
    expect(find.text('Old User'), findsNothing);

    firstResponse.complete(_usersResponse('old-user', 'Old'));
    await tester.pumpAndSettle();
    expect(find.text('New User'), findsOneWidget);
    expect(find.text('Old User'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an error state when the users request fails', (
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
