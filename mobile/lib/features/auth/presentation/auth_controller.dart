import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/env/env.dart';
import '../domain/auth_state.dart';
import '../domain/user.dart';
import '../data/auth_provider.dart';
import '../data/remote_auth_provider.dart';

class AuthController extends Notifier<AuthState> {
  String _cleanErrorMessage(Object error) {
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length);
    }
    return str;
  }

  /// Returns the error code if the error is an AuthApiException.
  String? _errorCode(Object error) {
    if (error is AuthApiException) {
      return error.code;
    }
    return null;
  }

  @override
  AuthState build() {
    Future.microtask(() async {
      if (kIsWeb) {
        unawaited(_initializeGoogleSignIn());
      }
      await checkAuthStatus();
    });

    return const AuthState();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Env.googleWebClientId.isNotEmpty
            ? Env.googleWebClientId
            : Env.googleAndroidClientId,
      );
    } catch (_) {}
  }

  /// Restores auth session and onboarding state from SharedPreferences.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      final repository = ref.read(authProvider);
      final user = await repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          hasSeenOnboarding: hasSeenOnboarding,
          isInitializing: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          hasSeenOnboarding: hasSeenOnboarding,
          isInitializing: false,
        );
      }
    } catch (e) {
      bool hasSeenOnboarding = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      } catch (_) {}
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _cleanErrorMessage(e),
        hasSeenOnboarding: hasSeenOnboarding,
        isInitializing: false,
      );
    }
  }

  /// Persist onboarding completion before publishing the new routing state.
  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final wasSaved = await prefs.setBool('has_seen_onboarding', true);
    if (!wasSaved) {
      throw StateError('Unable to save onboarding completion.');
    }
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      final user = await repository.signInWithEmail(email, password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      final code = _errorCode(e);
      if (code == 'EMAIL_NOT_VERIFIED') {
        // Redirect to verification screen
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          pendingVerificationEmail: email.toLowerCase().trim(),
          errorMessage: _cleanErrorMessage(e),
        );
        return false;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.signUpWithEmail(email, password, name);
      // Signup succeeded — navigate to verification screen
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        pendingVerificationEmail: email.toLowerCase().trim(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyEmail(String email, String otp) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.verifyEmail(email, otp);
      // Verification succeeded — navigate to login
      state = state
          .copyWith(status: AuthStatus.unauthenticated, errorMessage: null)
          .clearPending();
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        pendingVerificationEmail: email,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      final repository = ref.read(authProvider);
      await repository.resendVerification(email);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _cleanErrorMessage(e));
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.resetPassword(email);
      // OTP sent — navigate to reset password screen
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        pendingResetEmail: email.toLowerCase().trim(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> resetPasswordComplete(
    String email,
    String otp,
    String newPassword,
  ) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.resetPasswordWithOtp(email, otp, newPassword);
      // Password reset succeeded — navigate to login
      state = state.copyWith(status: AuthStatus.unauthenticated).clearPending();
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        pendingResetEmail: email,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      final user = await repository.signInWithGoogle();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final repository = ref.read(authProvider);
      await repository.signOut();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        hasSeenOnboarding: state.hasSeenOnboarding,
        isInitializing: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _cleanErrorMessage(e),
      );
    }
  }

  Future<bool> requestDeleteAccountOtp(String password) async {
    state = state.copyWith(errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.requestDeleteAccountOtp(password);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _cleanErrorMessage(e));
      return false;
    }
  }

  Future<bool> verifyDeleteAccountOtp(String otp) async {
    state = state.copyWith(errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.verifyDeleteAccountOtp(otp);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _cleanErrorMessage(e));
      return false;
    }
  }

  Future<bool> deleteAccount(String otp) async {
    state = state.copyWith(errorMessage: null);
    try {
      final repository = ref.read(authProvider);
      await repository.deleteAccount(otp);
      state = AuthState(
        status: AuthStatus.unauthenticated,
        hasSeenOnboarding: state.hasSeenOnboarding,
        isInitializing: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _cleanErrorMessage(e));
      return false;
    }
  }

  Future<User?> fetchMe() async {
    try {
      final repository = ref.read(authProvider);
      final user = await repository.fetchMe();
      state = state.copyWith(user: user, errorMessage: null);
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      final repository = ref.read(authProvider);
      await repository.updateUser(user);
      state = state.copyWith(user: user, errorMessage: null);
    } catch (e) {
      state = state.copyWith(errorMessage: _cleanErrorMessage(e));
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
