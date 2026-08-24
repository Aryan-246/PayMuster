import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:paymuster_mobile/features/admin/data/admin_api_client.dart';
import 'package:paymuster_mobile/features/admin/presentation/admin_settings_screen.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/l10n/app_localizations.dart';
import 'package:paymuster_mobile/l10n/language_controller.dart';
import 'package:paymuster_mobile/theme/theme_controller.dart';

class _FakeAuth implements AuthProviderBase {
  @override
  Future<String?> getAccessToken() async => 'token';
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

class _FakeAdminApi extends AdminApiClient {
  _FakeAdminApi(super.ref, {this.failure = false});

  bool failure;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getProviderHealth() async {
    calls += 1;
    if (failure) throw Exception('Provider health unavailable.');
    return {
      'freeOnly': true,
      'providers': [
        {
          'provider': 'paymuster',
          'kind': 'AUTH',
          'status': 'CONNECTED',
          'enabled': true,
        },
        {
          'provider': 'algolia',
          'kind': 'SEARCH',
          'status': 'DISABLED',
          'enabled': false,
          'fallback': 'database',
        },
      ],
    };
  }
}

Widget _screenWith({bool failure = false}) {
  final theme = ThemeController();
  final language = LanguageController();
  return ProviderScope(
    overrides: [
      authProvider.overrideWithValue(_FakeAuth()),
      adminApiClientProvider.overrideWith(
        (ref) => _FakeAdminApi(ref, failure: failure),
      ),
    ],
    child: LanguageScope(
      notifier: language,
      child: ThemeScope(
        notifier: theme,
        child: const MaterialApp(
          locale: Locale('en', 'IN'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminSettingsScreen(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'provider health renders connected and disabled fallback states',
    (tester) async {
      await tester.pumpWidget(_screenWith());
      await tester.pumpAndSettle();

      expect(find.text('paymuster'), findsOneWidget);
      expect(find.textContaining('CONNECTED'), findsOneWidget);
      expect(find.text('algolia'), findsOneWidget);
      expect(find.textContaining('DISABLED'), findsOneWidget);
      expect(find.textContaining('fallback: database'), findsOneWidget);
    },
  );

  testWidgets('provider health exposes retryable error state', (tester) async {
    await tester.pumpWidget(_screenWith(failure: true));
    await tester.pumpAndSettle();

    expect(find.text('Provider health unavailable.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}
