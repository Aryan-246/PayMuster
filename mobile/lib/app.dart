import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/paymuster_theme.dart';
import 'theme/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_controller.dart';
import 'widgets/paymuster_shell.dart';

import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/complete_profile_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/domain/auth_state.dart';

import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/presentation/more_screen.dart';
import 'features/dashboard/presentation/promotion_status_screen.dart';
import 'features/dashboard/presentation/career_screen.dart';
import 'features/dashboard/presentation/documents_screen.dart';
import 'features/dashboard/presentation/verification_screen.dart';

import 'features/company/presentation/company_switch_screen.dart';
import 'features/company/presentation/join_company_screen.dart';
import 'features/company/presentation/owner_dashboard_screen.dart';
import 'features/company/presentation/owner_request_screen.dart';
import 'features/company/presentation/company_info_screen.dart';
import 'features/company/presentation/join_requests_screen.dart';
import 'features/billing/presentation/billing_screen.dart';
import 'features/mail_supply/presentation/mail_supply_screen.dart';
import 'features/announcements/presentation/announcement_dispatch_screen.dart';
import 'features/billing/presentation/subscription_state_screen.dart';
import 'features/notifications/presentation/notification_center_screen.dart';
import 'features/ai/presentation/ai_assistant_screen.dart';

import 'features/sites/presentation/sites_screen.dart';
import 'features/announcements/presentation/notices_screen.dart';
import 'features/staff/presentation/worker_profile_screen.dart';
import 'features/staff/presentation/staff_directory_screen.dart';
import 'features/staff/presentation/staff_detail_screen.dart';
import 'features/staff/presentation/add_staff_screen.dart';
import 'features/attendance/presentation/attendance_screen.dart';
import 'features/payroll/presentation/payroll_screen.dart';
import 'features/settings/presentation/profile_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/reviews/presentation/review_submit_screen.dart';

import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/admin/presentation/admin_users_screen.dart';
import 'features/admin/presentation/admin_user_detail_screen.dart';
import 'features/admin/presentation/admin_owner_requests_screen.dart';
import 'features/admin/presentation/admin_companies_screen.dart';
import 'features/admin/presentation/admin_company_detail_screen.dart';
import 'features/admin/presentation/admin_sites_screen.dart';
import 'features/admin/presentation/admin_site_detail_screen.dart';
import 'features/admin/presentation/admin_attendance_screen.dart';
import 'features/admin/presentation/admin_payroll_screen.dart';
import 'features/admin/presentation/admin_audit_logs_screen.dart';
import 'features/admin/presentation/admin_notifications_screen.dart';
import 'features/admin/presentation/admin_documents_screen.dart';
import 'features/admin/presentation/admin_maintenance_screen.dart';
import 'features/admin/presentation/admin_ai_screen.dart';
import 'features/admin/presentation/admin_more_screen.dart';
import 'features/admin/presentation/admin_settings_screen.dart';
import 'features/admin/presentation/admin_profile_screen.dart';
import 'features/admin/presentation/admin_subscriptions_screen.dart';
import 'features/admin/presentation/admin_subscription_detail_screen.dart';
import 'features/admin/presentation/admin_payments_screen.dart';
import 'features/admin/presentation/admin_mail_supply_screen.dart';
import 'features/admin/presentation/admin_mail_composer_screen.dart';
import 'features/admin/presentation/admin_announcements_screen.dart';
import 'features/admin/presentation/admin_reviews_screen.dart';
import 'features/admin/presentation/admin_review_detail_screen.dart';
import 'features/admin/presentation/admin_provider_health_screen.dart';
import 'features/admin/presentation/admin_owners_screen.dart';
import 'features/admin/presentation/admin_reports_screen.dart';
import 'features/admin/presentation/admin_scaffold.dart';
import 'features/auth/domain/user.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorDashboardKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellDashboard',
);
final _shellNavigatorSitesKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellSites',
);
final _shellNavigatorAttendanceKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellAttendance',
);
final _shellNavigatorPayrollKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellPayroll',
);
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellSettings',
);

final _adminNavigatorDashboardKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminDashboard',
);
final _adminNavigatorUsersKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminUsers',
);
final _adminNavigatorCompaniesKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminCompanies',
);
final _adminNavigatorAuditKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminAudit',
);
final _adminNavigatorMoreKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminMore',
);

@visibleForTesting
String? authRedirect(
  String location,
  AuthState authState, {
  String? currentLocation,
  String? intendedLocation,
}) {
  final status = authState.status;
  final isAuthenticated = status == AuthStatus.authenticated;
  final isOnboarding = location == '/onboarding';
  final isSplash = location == '/splash';
  final isAuthPage =
      location == '/welcome' ||
      location == '/login' ||
      location == '/signup' ||
      location == '/forgot-password' ||
      location == '/complete-profile' ||
      location == '/verify-email' ||
      location == '/reset-password';

  if (authState.isInitializing) {
    if (isSplash) return null;
    return Uri(
      path: '/splash',
      queryParameters: {'redirect': currentLocation ?? location},
    ).toString();
  }

  if (status == AuthStatus.pendingVerification) {
    return location == '/verify-email' ? null : '/verify-email';
  }

  if (isAuthenticated) {
    final isSuperAdmin = authState.user?.role == UserRole.superAdmin;
    final intendedUri = _safeShellLocation(intendedLocation);
    if (isSplash && intendedUri != null) {
      if (isSuperAdmin && intendedUri.path.startsWith('/admin/')) {
        return intendedUri.toString();
      }
      if (!isSuperAdmin && intendedUri.path.startsWith('/app/')) {
        return intendedUri.toString();
      }
    }

    if (isSuperAdmin && !location.startsWith('/admin/')) {
      return '/admin/dashboard';
    }
    if (!isSuperAdmin && location.startsWith('/admin/')) {
      return '/app/dashboard';
    }
    if (location == '/' || isOnboarding || isSplash || isAuthPage) {
      return isSuperAdmin ? '/admin/dashboard' : '/app/dashboard';
    }
    return null;
  }

  if (isSplash) {
    return authState.hasSeenOnboarding ? '/welcome' : '/onboarding';
  }
  if (!authState.hasSeenOnboarding) {
    return isOnboarding ? null : '/onboarding';
  }

  if (isOnboarding) return '/welcome';
  if (isAuthPage) return null;

  return '/welcome';
}

Uri? _safeShellLocation(String? candidate) {
  if (candidate == null ||
      !candidate.startsWith('/') ||
      candidate.startsWith('//')) {
    return null;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      (!uri.path.startsWith('/admin/') && !uri.path.startsWith('/app/'))) {
    return null;
  }
  return uri;
}

final routerProvider = Provider<GoRouter>((ref) {
  final initialAuthState = ref.read(authControllerProvider);
  final notifier = ValueNotifier<AuthState>(initialAuthState);

  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => notifier.value = next,
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) => authRedirect(
      state.matchedLocation,
      ref.read(authControllerProvider),
      currentLocation: state.uri.toString(),
      intendedLocation: state.uri.queryParameters['redirect'],
    ),
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
      GoRoute(path: '/', redirect: (context, state) => '/splash'),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _adminNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
              GoRoute(
                path: '/admin/reports',
                builder: (context, state) => const AdminReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorUsersKey,
            routes: [
              GoRoute(
                path: '/admin/users',
                builder: (context, state) => AdminUsersScreen(
                  initialRole: state.uri.queryParameters['role'],
                  initialStatus: state.uri.queryParameters['status'],
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminUserDetailScreen(
                      userId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/owner-requests',
                builder: (context, state) => const AdminOwnerRequestsScreen(),
              ),
              GoRoute(
                path: '/admin/owners',
                builder: (context, state) => const AdminOwnersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorCompaniesKey,
            routes: [
              GoRoute(
                path: '/admin/companies',
                builder: (context, state) => const AdminCompaniesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminCompanyDetailScreen(
                      orgId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/sites',
                builder: (context, state) => const AdminSitesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminSiteDetailScreen(
                      siteId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/attendance',
                builder: (context, state) => const AdminAttendanceScreen(),
              ),
              GoRoute(
                path: '/admin/payroll',
                builder: (context, state) => const AdminPayrollScreen(),
              ),
              GoRoute(
                path: '/admin/subscriptions',
                builder: (context, state) => const AdminSubscriptionsScreen(),
                routes: [
                  GoRoute(
                    path: ':orgId',
                    builder: (context, state) =>
                        AdminSubscriptionDetailScreen(
                          orgId: state.pathParameters['orgId']!,
                        ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/payments',
                builder: (context, state) => const AdminPaymentsScreen(),
              ),
              GoRoute(
                path: '/admin/mail',
                builder: (context, state) => const AdminMailSupplyScreen(),
                routes: [
                  GoRoute(
                    path: 'compose',
                    builder: (context, state) =>
                        const AdminMailComposerScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/announcements',
                builder: (context, state) => const AdminAnnouncementsScreen(),
              ),
              GoRoute(
                path: '/admin/reviews',
                builder: (context, state) => const AdminReviewsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AdminReviewDetailScreen(
                      reviewId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorAuditKey,
            routes: [
              GoRoute(
                path: '/admin/audit-logs',
                builder: (context, state) => const AdminAuditLogsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _adminNavigatorMoreKey,
            routes: [
              GoRoute(
                path: '/admin/more',
                builder: (context, state) => const AdminMoreScreen(),
              ),
              GoRoute(
                path: '/admin/notifications',
                builder: (context, state) => const AdminNotificationsScreen(),
              ),
              GoRoute(
                path: '/admin/documents',
                builder: (context, state) => const AdminDocumentsScreen(),
              ),
              GoRoute(
                path: '/admin/maintenance',
                builder: (context, state) => const AdminMaintenanceScreen(),
              ),
              GoRoute(
                path: '/admin/ai',
                builder: (context, state) => const AdminAiScreen(),
              ),
              GoRoute(
                path: '/admin/provider-health',
                builder: (context, state) =>
                    const AdminProviderHealthScreen(),
              ),
              GoRoute(
                path: '/admin/settings',
                builder: (context, state) => const AdminSettingsScreen(),
              ),
              GoRoute(
                path: '/admin/profile',
                builder: (context, state) => const AdminProfileScreen(),
              ),
            ],
          ),
        ],
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
              GoRoute(
                path: '/app/owner-dashboard',
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
              GoRoute(
                path: '/app/billing',
                builder: (context, state) => const BillingScreen(),
              ),
              GoRoute(
                path: '/app/mail-supply',
                builder: (context, state) => const MailSupplyScreen(),
              ),
              GoRoute(
                path: '/app/announcement-dispatch',
                builder: (context, state) =>
                    const AnnouncementDispatchScreen(),
              ),
              GoRoute(
                path: '/app/subscription',
                builder: (context, state) =>
                    const SubscriptionStateScreen(),
              ),
              GoRoute(
                path: '/app/company-switch',
                builder: (context, state) => const CompanySwitchScreen(),
              ),
              GoRoute(
                path: '/app/owner-request',
                builder: (context, state) => const OwnerRequestScreen(),
              ),
              GoRoute(
                path: '/app/career',
                builder: (context, state) => const CareerScreen(),
              ),
              GoRoute(
                path: '/app/promotion-status',
                builder: (context, state) => const PromotionStatusScreen(),
              ),
              GoRoute(
                path: '/app/documents',
                builder: (context, state) => const DocumentsScreen(),
              ),
              GoRoute(
                path: '/app/verification',
                builder: (context, state) => const VerificationScreen(),
              ),

              GoRoute(
                path: '/app/workers/:id',
                builder: (context, state) =>
                    WorkerProfileScreen(workerId: state.pathParameters['id']!),
              ),

              // Owner staff module (owner.txt staff section).
              GoRoute(
                path: '/app/staff',
                builder: (context, state) => const StaffDirectoryScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const AddStaffScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => StaffDetailScreen(
                      staffId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/app/notifications',
                builder: (context, state) =>
                    const NotificationCenterScreen(),
              ),
              GoRoute(
                path: '/app/company-info',
                builder: (context, state) => const CompanyInfoScreen(),
              ),
              GoRoute(
                path: '/app/join-requests',
                builder: (context, state) => const JoinRequestsScreen(),
              ),
              GoRoute(
                path: '/app/ai-assistant',
                builder: (context, state) => const AiAssistantScreen(),
              ),
              GoRoute(
                path: '/app/review',
                builder: (context, state) => const ReviewSubmitScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSitesKey,
            routes: [
              GoRoute(
                path: '/app/sites',
                builder: (context, state) => const SitesScreen(),
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
              GoRoute(
                path: '/app/notices',
                builder: (context, state) => const NoticesScreen(),
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
                GlobalCupertinoLocalizations.delegate,
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
