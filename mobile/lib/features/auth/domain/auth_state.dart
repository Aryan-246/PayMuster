import 'user.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingVerification,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool hasSeenOnboarding;
  final bool isInitializing;
  final String? pendingVerificationEmail;
  final String? pendingResetEmail;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.hasSeenOnboarding = false,
    this.isInitializing = true,
    this.pendingVerificationEmail,
    this.pendingResetEmail,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? hasSeenOnboarding,
    bool? isInitializing,
    String? pendingVerificationEmail,
    String? pendingResetEmail,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isInitializing: isInitializing ?? this.isInitializing,
      pendingVerificationEmail: pendingVerificationEmail ?? this.pendingVerificationEmail,
      pendingResetEmail: pendingResetEmail ?? this.pendingResetEmail,
    );
  }

  /// Creates a copy that explicitly clears pending fields.
  AuthState clearPending() {
    return AuthState(
      status: status,
      user: user,
      errorMessage: errorMessage,
      hasSeenOnboarding: hasSeenOnboarding,
      isInitializing: isInitializing,
    );
  }
}
