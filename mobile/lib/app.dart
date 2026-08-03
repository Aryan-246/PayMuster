import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/paymuster_theme.dart';
import 'theme/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_controller.dart';
import 'widgets/paymuster_shell.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/staff/presentation/worker_profile_screen.dart';
import 'features/attendance/presentation/attendance_screen.dart';
import 'features/payroll/presentation/payroll_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/complete_profile_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/dashboard/presentation/more_screen.dart';
import 'features/settings/presentation/profile_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/sites/presentation/sites_screen.dart';
import 'features/company/presentation/join_company_screen.dart';
// Create placeholder screens for the other tabs
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

void main() {
  runApp(const ProviderScope(child: PayMusterApp()));
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _shellNavigatorSitesKey = GlobalKey<NavigatorState>(debugLabel: 'sites');
final _shellNavigatorAttendanceKey = GlobalKey<NavigatorState>(debugLabel: 'attendance');
final _shellNavigatorPayrollKey = GlobalKey<NavigatorState>(debugLabel: 'payroll');
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    notifier.value = next;
  });

  final router = GoRouter(
    initialLocation: '/splash',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = notifier.value;
      final status = authState.status;
      final loc = state.matchedLocation;

      if (authState.isInitializing) {
        return loc == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState.user != null && status != AuthStatus.unauthenticated;
      final isAuthPage = loc == '/login' ||
          loc == '/signup' ||
          loc == '/welcome' ||
          loc == '/forgot-password' ||
          loc == '/verify-email' ||
          loc == '/reset-password';

      // Handle pending verification
      if (status == AuthStatus.pendingVerification) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      if (isAuthenticated) {
        if (loc == '/' || loc.startsWith('/app/dashboard')) {
          if (loc != '/app/dashboard') {
            return '/app/dashboard';
          }
          return null; // Stay on /app/dashboard
        }

        if (isAuthPage || loc == '/splash' || loc == '/onboarding') {
          return '/app/dashboard';
        }
        return null;
      }

      if (!authState.hasSeenOnboarding) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      if (isAuthPage) return null;

      return '/welcome';
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/splash',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return PayMusterShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/app/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/app/join-company',
                builder: (context, state) => const JoinCompanyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSitesKey,
            routes: [
              GoRoute(
                path: '/app/sites',
                builder: (context, state) => const SitesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => WorkerProfileScreen(
                      workerId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAttendanceKey,
            routes: [
              GoRoute(
                path: '/app/attendance',
                builder: (context, state) => const AttendanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPayrollKey,
            routes: [
              GoRoute(
                path: '/app/payroll',
                builder: (context, state) => const PayrollScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/app/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});

class PayMusterApp extends ConsumerStatefulWidget {
  const PayMusterApp({super.key});

  @override
  ConsumerState<PayMusterApp> createState() => _PayMusterAppState();
}

class _PayMusterAppState extends ConsumerState<PayMusterApp> {
  late final ThemeController _themeController;
  late final LanguageController _languageController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController()..load();
    _languageController = LanguageController()..load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      notifier: _languageController,
      child: ThemeScope(
        notifier: _themeController,
        child: ListenableBuilder(
          listenable: Listenable.merge([_themeController, _languageController]),
          builder: (context, _) {
            return MaterialApp.router(
              title: 'PayMuster Mobile',
              locale: _languageController.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: PayMusterTheme.lightTheme(),
              darkTheme: _themeController.darkTheme,
              themeMode: _themeController.materialThemeMode,
              routerConfig: ref.watch(routerProvider),
            );
          },
        ),
      ),
    );
  }
}
