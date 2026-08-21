import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user.dart';
import 'remote_auth_provider.dart';

abstract class AuthProviderBase {
  Future<User> signInWithEmail(String email, String password);
  Future<User> signUpWithEmail(String email, String password, String name);
  Future<User> signInWithGoogle();
  Future<User> signInWithApple();
  Future<void> signOut();
  Future<bool> refreshAccessToken();
  Future<void> requestDeleteAccountOtp(String password);
  Future<void> verifyDeleteAccountOtp(String otp);
  Future<void> deleteAccount(String otp);
  Future<void> resetPassword(String email);
  Future<void> verifyEmail(String email, String otp);
  Future<void> resendVerification(String email);
  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  );
  Future<User?> getCurrentUser();
  Future<User> fetchMe();
  Future<String?> getAccessToken();
  Future<void> updateUser(User user);
}

// Production provider — uses RemoteAuthProvider against the real backend
final authProvider = Provider<AuthProviderBase>((ref) {
  return RemoteAuthProvider();
});
