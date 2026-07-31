import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user.dart';

abstract class AuthRepository {
  Future<User> signIn(String email, String password);
  Future<void> signOut();
  Future<User?> getCurrentUser();
}

class MockAuthRepository implements AuthRepository {
  User? _currentUser;

  @override
  Future<User> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network request
    
    if (email == 'admin@paymuster.com' && password == 'admin123') {
      _currentUser = const User(
        id: 'user_123',
        email: 'admin@paymuster.com',
        role: 'admin',
        organizationId: 'org_1',
        name: 'Admin User',
      );
      return _currentUser!;
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  @override
  Future<User?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _currentUser;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Return mock for now. Switch to SupabaseAuthRepository when ready.
  return MockAuthRepository();
});
