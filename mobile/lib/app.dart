import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/paymuster_theme.dart';
import 'theme/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_controller.dart';
import 'widgets/paymuster_shell.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/staff/presentation/staff_list_screen.dart';
import 'features/staff/presentation/worker_profile_screen.dart';

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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/app/dashboard',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isSplash = authState.status == AuthStatus.initial || authState.status == AuthStatus.loading;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (isSplash && !isAuth) return null; // let it stay on splash/login if it is loading

      if (!isAuth && !isGoingToLogin) {
        return '/login';
      }
      
      if (isAuth && isGoingToLogin) {
        return '/app/dashboard';
      }
      
      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/app/dashboard',
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
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSitesKey,
            routes: [
              GoRoute(
                path: '/app/sites',
                builder: (context, state) => const StaffListScreen(),
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
                builder: (context, state) => const PlaceholderScreen('Mark Attendance'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPayrollKey,
            routes: [
              GoRoute(
                path: '/app/payroll',
                builder: (context, state) => const PlaceholderScreen('Payroll'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
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
        child: MaterialApp.router(
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
        ),
      ),
    );
  }
}
