import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/app.dart';
import 'package:paymuster_mobile/features/auth/domain/auth_state.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';

void main() {
  group('authRedirect', () {
    test('holds an admin deep link on splash during initialization', () {
      const authState = AuthState();

      expect(
        authRedirect(
          '/admin/documents',
          authState,
          currentLocation: '/admin/documents',
        ),
        '/splash?redirect=%2Fadmin%2Fdocuments',
      );
    });

    test('restores a super admin deep link and query after initialization', () {
      const authState = AuthState(
        status: AuthStatus.authenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
        user: User(
          id: 'super-admin',
          email: 'super.admin@example.com',
          role: UserRole.superAdmin,
        ),
      );

      expect(
        authRedirect(
          '/splash',
          authState,
          intendedLocation: '/admin/users?role=OWNER&status=ACTIVE',
        ),
        '/admin/users?role=OWNER&status=ACTIVE',
      );
    });

    test('does not restore an admin deep link for a normal user', () {
      const authState = AuthState(
        status: AuthStatus.authenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
        user: User(
          id: 'staff-user',
          email: 'staff@example.com',
          role: UserRole.staff,
        ),
      );

      expect(
        authRedirect(
          '/splash',
          authState,
          intendedLocation: '/admin/documents',
        ),
        '/app/dashboard',
      );
    });

    test('resolves splash to onboarding for a fresh unauthenticated user', () {
      const authState = AuthState(
        status: AuthStatus.unauthenticated,
        isInitializing: false,
      );

      expect(
        authRedirect(
          '/splash',
          authState,
          intendedLocation: '/admin/documents',
        ),
        '/onboarding',
      );
    });

    test('keeps a fresh unauthenticated user on onboarding', () {
      const authState = AuthState(
        status: AuthStatus.unauthenticated,
        isInitializing: false,
      );

      expect(authRedirect('/onboarding', authState), isNull);
    });

    test('sends a completed unauthenticated user to welcome', () {
      const authState = AuthState(
        status: AuthStatus.unauthenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
      );

      expect(authRedirect('/onboarding', authState), '/welcome');
    });

    test('sends an authenticated super admin to the admin dashboard', () {
      const authState = AuthState(
        status: AuthStatus.authenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
        user: User(
          id: 'super-admin',
          email: 'super.admin@example.com',
          role: UserRole.superAdmin,
        ),
      );

      expect(authRedirect('/onboarding', authState), '/admin/dashboard');
    });

    test('keeps the Notices deep link for a normal authenticated user', () {
      const authState = AuthState(
        status: AuthStatus.authenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
        user: User(
          id: 'staff-user',
          email: 'staff@example.com',
          role: UserRole.staff,
        ),
      );

      expect(authRedirect('/app/notices', authState), isNull);
    });

    test('blocks a normal authenticated user from admin routes', () {
      const authState = AuthState(
        status: AuthStatus.authenticated,
        hasSeenOnboarding: true,
        isInitializing: false,
        user: User(
          id: 'staff-user',
          email: 'staff@example.com',
          role: UserRole.staff,
        ),
      );

      expect(authRedirect('/admin/users', authState), '/app/dashboard');
    });
  });
}
