import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_user_detail_screen.dart';
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

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response _userDetailResponse() {
  return _jsonResponse({
    'data': {
      'user': {
        'id': 'target-user',
        'publicId': 'PM-USR-TEST',
        'email': 'synthetic@example.com',
        'firstName': 'Synthetic',
        'lastName': 'Viewer',
        'role': 'VIEWER',
        'status': 'VERIFIED',
        'isDisabled': false,
        'emailVerified': true,
      },
      'ownerRequests': <dynamic>[],
      'auditLogs': <dynamic>[],
      'documents': <dynamic>[],
    },
  }, 200);
}

http.Response _usersResponse({required bool includeTarget}) {
  final users = includeTarget
      ? [
          {
            'id': 'target-user',
            'publicId': 'PM-USR-TEST',
            'email': 'synthetic@example.com',
            'firstName': 'Synthetic',
            'lastName': 'Viewer',
            'role': 'VIEWER',
            'status': 'VERIFIED',
            'isDisabled': false,
            'emailVerified': true,
          },
        ]
      : <Map<String, dynamic>>[];
  return _jsonResponse({
    'data': users,
    'meta': {'total': users.length, 'page': 1, 'totalPages': 1},
  }, 200);
}

Future<GoRouter> _pumpDetail(WidgetTester tester, http.Client client) async {
  final router = GoRouter(
    initialLocation: '/admin/users/target-user',
    routes: [
      GoRoute(
        path: '/admin/users',
        builder: (context, state) =>
            const Scaffold(body: Text('Users destination')),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                AdminUserDetailScreen(userId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWithValue(_FakeAuthProvider()),
        adminApiClientProvider.overrideWith((ref) {
          final api = AdminApiClient(ref, client: client);
          ref.onDispose(api.close);
          return api;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _submitDeletion(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Delete Account'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField),
    'Synthetic local deletion regression',
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  testWidgets(
    'successful deletion skips deleted-detail refresh and navigates to users',
    (tester) async {
      var detailGets = 0;
      var deletePosts = 0;
      Map<String, dynamic>? deletionBody;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/admin/users/target-user') {
          detailGets += 1;
          return _userDetailResponse();
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/admin/users/target-user/action') {
          deletePosts += 1;
          deletionBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'data': {
              'message': 'User account deleted',
              'deletedAt': '2026-08-19T10:00:00.000Z',
            },
          }, 200);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });

      final router = await _pumpDetail(tester, client);
      expect(find.text('Synthetic Viewer'), findsOneWidget);

      await _submitDeletion(tester);

      expect(deletePosts, 1);
      expect(detailGets, 1);
      expect(deletionBody, {
        'action': 'DELETE',
        'reason': 'Synthetic local deletion regression',
      });
      expect(router.routeInformationProvider.value.uri.path, '/admin/users');
      expect(find.text('Users destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful deletion refreshes the retained users route after a deep link',
    (tester) async {
      var listGets = 0;
      var detailGets = 0;
      var deletePosts = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/admin/users') {
          listGets += 1;
          return _usersResponse(includeTarget: listGets == 1);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/admin/users/target-user') {
          detailGets += 1;
          return _userDetailResponse();
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/admin/users/target-user/action') {
          deletePosts += 1;
          return _jsonResponse({
            'data': {
              'message': 'User account deleted',
              'deletedAt': '2026-08-19T10:00:00.000Z',
            },
          }, 200);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });
      final router = GoRouter(
        initialLocation: '/admin/users/target-user',
        routes: [
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    AdminUserDetailScreen(userId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWithValue(_FakeAuthProvider()),
            adminApiClientProvider.overrideWith((ref) {
              final api = AdminApiClient(ref, client: client);
              ref.onDispose(api.close);
              return api;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(listGets, 1);
      expect(detailGets, 1);
      expect(find.text('Synthetic Viewer'), findsWidgets);

      await _submitDeletion(tester);

      expect(deletePosts, 1);
      expect(detailGets, 1);
      expect(listGets, 2);
      expect(router.routeInformationProvider.value.uri.path, '/admin/users');
      expect(find.text('User Management (0)'), findsOneWidget);
      expect(find.text('Synthetic Viewer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deletion requires a reason and cancel sends no mutation', (
    tester,
  ) async {
    var detailGets = 0;
    var deletePosts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/admin/users/target-user') {
        detailGets += 1;
        return _userDetailResponse();
      }
      if (request.method == 'POST') {
        deletePosts += 1;
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });

    final router = await _pumpDetail(tester, client);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete Account'));
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete Account'),
    );
    expect(deleteButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(deletePosts, 0);
    expect(detailGets, 1);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/admin/users/target-user',
    );
    expect(find.text('Synthetic Viewer'), findsOneWidget);
    expect(find.text('Delete User Account?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed deletion remains on the profile and reports the error', (
    tester,
  ) async {
    var detailGets = 0;
    var deletePosts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/admin/users/target-user') {
        detailGets += 1;
        return _userDetailResponse();
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/admin/users/target-user/action') {
        deletePosts += 1;
        return _jsonResponse({
          'error': {
            'code': 'CONFLICT',
            'message': 'User account has already been deleted',
          },
        }, 409);
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });

    final router = await _pumpDetail(tester, client);
    await _submitDeletion(tester);

    expect(deletePosts, 1);
    expect(detailGets, 1);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/admin/users/target-user',
    );
    expect(find.text('Synthetic Viewer'), findsOneWidget);
    expect(
      find.textContaining('User account has already been deleted'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
