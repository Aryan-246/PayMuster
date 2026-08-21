import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paymuster_mobile/features/auth/domain/auth_state.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/features/auth/presentation/auth_controller.dart';
import 'package:paymuster_mobile/features/company/data/company_provider.dart';
import 'package:paymuster_mobile/features/company/presentation/owner_dashboard_screen.dart';
import 'package:paymuster_mobile/features/company/presentation/owner_request_screen.dart';
import 'package:paymuster_mobile/features/dashboard/presentation/promotion_status_screen.dart';

const _staffUser = User(
  id: 'user-1',
  email: 'applicant@example.com',
  role: UserRole.staff,
  name: 'Applicant',
);

const _ownerUser = User(
  id: 'user-1',
  email: 'owner@example.com',
  role: UserRole.owner,
  organizationId: 'org-1',
  name: 'Owner',
);

OwnerRequest _ownerRequest({
  String status = 'PENDING',
  String? rejectionReason,
}) {
  return OwnerRequest(
    id: 'request-1',
    publicId: 'OWN-0001',
    companyName: 'Acme Payroll',
    status: status,
    rejectionReason: rejectionReason,
  );
}

const _overview = CompanyOverview(
  id: 'org-1',
  publicId: 'ORG-0001',
  name: 'Acme Payroll',
  joinCode: 'ACME1234',
  referenceCode: 'ACME-REF',
  userCount: 12,
  siteCount: 3,
  staffCount: 9,
  financialSummary: CompanyFinancialSummary(
    includedExpenseStatuses: ['APPROVED', 'REIMBURSED'],
    siteLinkedExpenseTotal: '1250.50',
    companyLevelExpenseTotal: '300.25',
    recordedPayRunCount: 4,
    recordedPayRunTotal: '84500.75',
  ),
);

class _TestAuthController extends AuthController {
  _TestAuthController({required this.initialUser, this.refreshedUser});

  final User initialUser;
  final User? refreshedUser;
  int fetchCalls = 0;

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      isInitializing: false,
      hasSeenOnboarding: true,
      user: initialUser,
    );
  }

  @override
  Future<User?> fetchMe() async {
    fetchCalls += 1;
    final user = refreshedUser;
    if (user != null) state = state.copyWith(user: user);
    return user;
  }
}

class _FakeCompanyApi extends CompanyApi {
  _FakeCompanyApi(
    super.ref, {
    this.myRequest,
    this.overview = _overview,
    this.failure,
    this.myRequestFuture,
    this.overviewFuture,
  });

  final OwnerRequest? myRequest;
  final CompanyOverview overview;
  final Object? failure;
  final Future<OwnerRequest?>? myRequestFuture;
  final Future<CompanyOverview>? overviewFuture;

  int submissionCalls = 0;
  int overviewCalls = 0;
  String? overviewCompanyId;
  String? submittedCompanyName;
  String? submittedCompanyAddress;
  String? submittedGstin;
  String? submittedBusinessRegistrationUrl;
  String? submittedIdentityProofUrl;

  @override
  Future<OwnerRequest?> getMyOwnerRequest() async {
    if (failure != null) throw failure!;
    if (myRequestFuture != null) return myRequestFuture!;
    return myRequest;
  }

  @override
  Future<OwnerRequest> requestOwnership(
    String companyName, {
    String? companyAddress,
    String? gstin,
    String? businessRegistrationUrl,
    String? identityProofUrl,
  }) async {
    submissionCalls += 1;
    submittedCompanyName = companyName;
    submittedCompanyAddress = companyAddress;
    submittedGstin = gstin;
    submittedBusinessRegistrationUrl = businessRegistrationUrl;
    submittedIdentityProofUrl = identityProofUrl;
    if (failure != null) throw failure!;
    return _ownerRequest();
  }

  @override
  Future<CompanyOverview> getOverview(String companyId) async {
    overviewCalls += 1;
    overviewCompanyId = companyId;
    if (failure != null) throw failure!;
    if (overviewFuture != null) return overviewFuture!;
    return overview;
  }
}

class _ScreenHarness {
  _ScreenHarness({
    required this.widget,
    required this.companyApi,
    required this.companyApiCreated,
  });

  final Widget widget;
  final _FakeCompanyApi Function() companyApi;
  final bool Function() companyApiCreated;
}

_ScreenHarness _screenHarness({
  required Widget screen,
  User user = _staffUser,
  User? refreshedUser,
  OwnerRequest? myRequest,
  CompanyOverview overview = _overview,
  Object? failure,
  Future<OwnerRequest?>? myRequestFuture,
  Future<CompanyOverview>? overviewFuture,
}) {
  late _FakeCompanyApi api;
  var apiCreated = false;
  final widget = ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _TestAuthController(
          initialUser: user,
          refreshedUser: refreshedUser,
        ),
      ),
      companyProvider.overrideWith((ref) {
        apiCreated = true;
        api = _FakeCompanyApi(
          ref,
          myRequest: myRequest,
          overview: overview,
          failure: failure,
          myRequestFuture: myRequestFuture,
          overviewFuture: overviewFuture,
        );
        return api;
      }),
    ],
    child: MaterialApp(home: screen),
  );
  return _ScreenHarness(
    widget: widget,
    companyApi: () => api,
    companyApiCreated: () => apiCreated,
  );
}

Finder _field(String key) {
  return find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  group('OwnerRequestScreen', () {
    testWidgets('shows all five bounded application fields', (tester) async {
      final harness = _screenHarness(screen: const OwnerRequestScreen());

      await tester.pumpWidget(harness.widget);

      expect(find.byKey(const Key('owner-company-name')), findsOneWidget);
      expect(find.byKey(const Key('owner-company-address')), findsOneWidget);
      expect(find.byKey(const Key('owner-gstin')), findsOneWidget);
      expect(
        find.byKey(const Key('owner-business-registration-url')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('owner-identity-proof-url')), findsOneWidget);
      expect(find.byKey(const Key('owner-submit-request')), findsOneWidget);
    });

    testWidgets('rejects short names and non-HTTPS evidence URLs', (
      tester,
    ) async {
      final harness = _screenHarness(screen: const OwnerRequestScreen());
      await tester.pumpWidget(harness.widget);

      await tester.enterText(_field('owner-company-name'), 'A');
      await tester.enterText(
        _field('owner-business-registration-url'),
        'http://example.com/registration',
      );
      await tester.enterText(_field('owner-identity-proof-url'), 'not-a-url');
      await _scrollTo(tester, find.byKey(const Key('owner-submit-request')));
      await tester.tap(find.byKey(const Key('owner-submit-request')));
      await tester.pump();

      expect(find.text('Enter at least 2 characters'), findsOneWidget);
      expect(find.text('Enter a valid HTTPS URL'), findsNWidgets(2));
      expect(harness.companyApiCreated(), isFalse);
    });

    testWidgets('submits every field and routes to status', (tester) async {
      late _FakeCompanyApi api;
      final router = GoRouter(
        initialLocation: '/owner-request',
        routes: [
          GoRoute(
            path: '/owner-request',
            builder: (_, _) => const OwnerRequestScreen(),
          ),
          GoRoute(
            path: '/app/promotion-status',
            builder: (_, _) => const Scaffold(body: Text('Status destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companyProvider.overrideWith((ref) {
              api = _FakeCompanyApi(ref);
              return api;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.enterText(_field('owner-company-name'), 'Acme Payroll');
      await tester.enterText(_field('owner-company-address'), '1 Main Street');
      await tester.enterText(_field('owner-gstin'), 'GSTIN-123');
      await tester.enterText(
        _field('owner-business-registration-url'),
        'https://example.com/registration',
      );
      await tester.enterText(
        _field('owner-identity-proof-url'),
        'https://example.com/identity',
      );
      await _scrollTo(tester, find.byKey(const Key('owner-submit-request')));
      await tester.tap(find.byKey(const Key('owner-submit-request')));
      await tester.pumpAndSettle();

      expect(api.submissionCalls, 1);
      expect(api.submittedCompanyName, 'Acme Payroll');
      expect(api.submittedCompanyAddress, '1 Main Street');
      expect(api.submittedGstin, 'GSTIN-123');
      expect(
        api.submittedBusinessRegistrationUrl,
        'https://example.com/registration',
      );
      expect(api.submittedIdentityProofUrl, 'https://example.com/identity');
      expect(find.text('Status destination'), findsOneWidget);
    });
  });

  group('PromotionStatusScreen', () {
    testWidgets('renders the empty application state', (tester) async {
      final harness = _screenHarness(screen: const PromotionStatusScreen());

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('No Active Promotion Requests'), findsOneWidget);
      expect(find.text('Apply for Company Ownership'), findsOneWidget);
    });

    testWidgets('renders pending application details', (tester) async {
      final harness = _screenHarness(
        screen: const PromotionStatusScreen(),
        myRequest: _ownerRequest(),
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Request Pending Review'), findsOneWidget);
      expect(find.text('Company: Acme Payroll'), findsOneWidget);
      expect(find.text('Request ID: OWN-0001'), findsOneWidget);
    });

    testWidgets('renders rejection reason and resubmission action', (
      tester,
    ) async {
      final harness = _screenHarness(
        screen: const PromotionStatusScreen(),
        myRequest: _ownerRequest(
          status: 'REJECTED',
          rejectionReason: 'Registration evidence could not be verified.',
        ),
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Request Not Approved'), findsOneWidget);
      expect(
        find.text('Registration evidence could not be verified.'),
        findsOneWidget,
      );
      expect(find.text('Re-submit Request'), findsOneWidget);
    });

    testWidgets('fails closed when refreshed identity lacks Owner context', (
      tester,
    ) async {
      final harness = _screenHarness(
        screen: const PromotionStatusScreen(),
        myRequest: _ownerRequest(status: 'APPROVED'),
        refreshedUser: _staffUser,
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Owner Dashboard'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not ready for the Owner dashboard'),
        findsOneWidget,
      );
      expect(find.text('Open Owner Dashboard'), findsOneWidget);
    });

    testWidgets('refreshes identity before opening Owner dashboard', (
      tester,
    ) async {
      late _TestAuthController authController;
      final router = GoRouter(
        initialLocation: '/status',
        routes: [
          GoRoute(
            path: '/status',
            builder: (_, _) => const PromotionStatusScreen(),
          ),
          GoRoute(
            path: '/app/owner-dashboard',
            builder: (_, _) => const Scaffold(body: Text('Owner destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() {
              authController = _TestAuthController(
                initialUser: _staffUser,
                refreshedUser: _ownerUser,
              );
              return authController;
            }),
            companyProvider.overrideWith(
              (ref) => _FakeCompanyApi(
                ref,
                myRequest: _ownerRequest(status: 'APPROVED'),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Owner Dashboard'));
      await tester.pumpAndSettle();

      expect(authController.fetchCalls, 1);
      expect(find.text('Owner destination'), findsOneWidget);
    });
  });

  group('OwnerDashboardScreen', () {
    testWidgets('does not request data without active Owner context', (
      tester,
    ) async {
      final harness = _screenHarness(
        screen: const OwnerDashboardScreen(),
        user: _staffUser,
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Company overview unavailable'), findsOneWidget);
      expect(
        find.text(
          'Your account does not have an active Owner company context.',
        ),
        findsOneWidget,
      );
      expect(harness.companyApiCreated(), isFalse);
    });

    testWidgets('shows loading while the overview request is unresolved', (
      tester,
    ) async {
      final pendingOverview = Completer<CompanyOverview>();
      final harness = _screenHarness(
        screen: const OwnerDashboardScreen(),
        user: _ownerUser,
        overviewFuture: pendingOverview.future,
      );

      await tester.pumpWidget(harness.widget);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(harness.companyApi().overviewCompanyId, 'org-1');
      pendingOverview.complete(_overview);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'renders real company identifiers, counts, and financial history',
      (tester) async {
        final harness = _screenHarness(
          screen: const OwnerDashboardScreen(),
          user: _ownerUser,
        );

        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        expect(find.text('Acme Payroll'), findsOneWidget);
        expect(find.text('ORG-0001'), findsOneWidget);
        expect(find.text('ACME1234'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Financial History'), findsOneWidget);
        expect(find.text('Site-linked expenses'), findsOneWidget);
        expect(find.text('Company-level expenses'), findsOneWidget);
        expect(find.text('INR 1250.50'), findsOneWidget);
        expect(find.text('INR 300.25'), findsOneWidget);
        expect(find.text('Recorded pay runs'), findsOneWidget);
        expect(find.text('Recorded payroll total'), findsOneWidget);
        expect(find.text('INR 84500.75'), findsOneWidget);
        expect(
          find.textContaining('do not indicate payment or disbursement'),
          findsOneWidget,
        );
        expect(find.text('Pending'), findsNothing);
        expect(find.text('Paid'), findsNothing);
        expect(harness.companyApi().overviewCompanyId, 'org-1');
      },
    );

    testWidgets('shows a retryable company overview error', (tester) async {
      final harness = _screenHarness(
        screen: const OwnerDashboardScreen(),
        user: _ownerUser,
        failure: const CompanyApiException(
          'Company service unavailable.',
          code: 'SERVICE_UNAVAILABLE',
          statusCode: 503,
        ),
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Company overview unavailable'), findsOneWidget);
      expect(find.text('Company service unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
