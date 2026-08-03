import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paymuster_mobile/l10n/app_localizations.dart';
import 'package:paymuster_mobile/features/auth/domain/auth_state.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthController extends Notifier<AuthState> implements AuthController {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      isInitializing: false,
      hasSeenOnboarding: true,
      user: User(id: '1', email: 'worker@test.com', role: UserRole.staff, name: 'Worker'),
    );
  }

  @override
  Future<bool> requestDeleteAccountOtp(String password) async {
    return true;
  }

  @override
  Future<void> fetchMe() async {}

  @override
  Future<bool> verifyDeleteAccountOtp(String otp) async {
    return true;
  }

  @override
  Future<bool> deleteAccount(String otp) async {
    state = const AuthState(status: AuthStatus.unauthenticated, isInitializing: false);
    return true;
  }

  @override
  Future<void> checkAuthStatus() async {}
  @override
  void markOnboardingSeen() {}
  @override
  Future<bool> signIn(String email, String password) async => true;
  @override
  Future<bool> signUp(String email, String password, String name) async => true;
  @override
  Future<bool> signInWithGoogle() async => true;
  @override
  Future<bool> requestPasswordReset(String email) async => true;
  @override
  Future<bool> verifyEmail(String email, String otp) async => true;
  @override
  Future<bool> resendVerification(String email) async => true;
  @override
  Future<bool> resetPasswordComplete(String email, String otp, String newPassword) async => true;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateUser(User user) async {}
}

void main() {
  testWidgets('test bhojpuri locale', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => MockAuthController()),
        ],
        child: MaterialApp(
          locale: const Locale('bho', 'IN'), // Bhojpuri
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RefreshIndicator(
              onRefresh: _dummy,
              child: CustomScrollView(slivers: [SliverToBoxAdapter(child: Text('test'))]),
            ),
          ),
        ),
      ),
    );
    
    await tester.pump();
    if (tester.takeException() != null) {
      debugPrint('Exception found: ${tester.takeException()}');
    }
  });
}
Future<void> _dummy() async {}
