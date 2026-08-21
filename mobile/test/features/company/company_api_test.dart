import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paymuster_mobile/features/auth/data/auth_provider.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/features/company/data/company_provider.dart';

class _FakeAuthProvider implements AuthProviderBase {
  String? accessToken = 'access-token';
  bool refreshResult = false;
  int refreshCalls = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<bool> refreshAccessToken() async {
    refreshCalls += 1;
    if (refreshResult) accessToken = 'refreshed-token';
    return refreshResult;
  }

  @override
  Future<void> deleteAccount(String otp) async {}

  @override
  Future<User> fetchMe() => throw UnimplementedError();

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<void> requestDeleteAccountOtp(String password) async {}

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> resetPasswordWithOtp(
    String email,
    String otp,
    String newPassword,
  ) async {}

  @override
  Future<User> signInWithApple() => throw UnimplementedError();

  @override
  Future<User> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<User> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<User> signUpWithEmail(String email, String password, String name) =>
      throw UnimplementedError();

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<void> verifyDeleteAccountOtp(String otp) async {}

  @override
  Future<void> verifyEmail(String email, String otp) async {}
}

Provider<CompanyApi> _companyProviderFor(http.Client client) {
  return Provider<CompanyApi>((ref) {
    final api = CompanyApi(ref, client: client);
    ref.onDispose(api.close);
    return api;
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:4000');
  });

  test('loads the personal Owner request from the correct route', () async {
    final auth = _FakeAuthProvider();
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return _jsonResponse({
        'data': {
          'id': 'request-1',
          'publicId': 'OWN-0001',
          'companyName': 'Acme Payroll',
          'status': 'pending',
        },
      }, 200);
    });
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    final request = await container.read(provider).getMyOwnerRequest();

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/v1/company/owner-request/my');
    expect(capturedRequest.headers['authorization'], 'Bearer access-token');
    expect(capturedRequest.headers.containsKey('x-company-id'), isFalse);
    expect(request?.id, 'request-1');
    expect(request?.status, 'PENDING');
  });

  test('accepts a null personal Owner request response', () async {
    final auth = _FakeAuthProvider();
    final client = MockClient((_) async => _jsonResponse({'data': null}, 200));
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    expect(await container.read(provider).getMyOwnerRequest(), isNull);
  });

  test('sends explicit tenant context when loading company overview', () async {
    final auth = _FakeAuthProvider();
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return _jsonResponse({
        'data': {
          'id': 'org-1',
          'publicId': 'ORG-0001',
          'name': 'Acme Payroll',
          'joinCode': 'ACME1234',
          'referenceCode': 'ACME-REF',
          'settings': {'currency': 'INR'},
          '_count': {'users': 12, 'sites': 3, 'staff': 9},
          'financialSummary': {
            'expenses': {
              'includedStatuses': ['APPROVED', 'REIMBURSED'],
              'siteLinkedTotal': '1250.50',
              'companyLevelTotal': '300.25',
            },
            'payRuns': {'recordedCount': 4, 'recordedTotal': '84500.75'},
          },
        },
      }, 200);
    });
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    final overview = await container.read(provider).getOverview('org-1');

    expect(capturedRequest.url.path, '/api/v1/company/');
    expect(capturedRequest.headers['x-company-id'], 'org-1');
    expect(overview.name, 'Acme Payroll');
    expect(overview.currency, 'INR');
    expect(overview.userCount, 12);
    expect(overview.siteCount, 3);
    expect(overview.staffCount, 9);
    expect(overview.financialSummary.includedExpenseStatuses, [
      'APPROVED',
      'REIMBURSED',
    ]);
    expect(overview.financialSummary.siteLinkedExpenseTotal, '1250.50');
    expect(overview.financialSummary.companyLevelExpenseTotal, '300.25');
    expect(overview.financialSummary.recordedPayRunCount, 4);
    expect(overview.financialSummary.recordedPayRunTotal, '84500.75');
  });

  test('omits blank optional Owner application fields', () async {
    final auth = _FakeAuthProvider();
    late Map<String, dynamic> capturedBody;
    final client = MockClient((request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse({
        'data': {
          'id': 'request-2',
          'companyName': 'Acme Payroll',
          'companyAddress': '1 Main Street',
          'businessRegistrationUrl': 'https://example.com/registration',
          'status': 'PENDING',
        },
      }, 201);
    });
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await container
        .read(provider)
        .requestOwnership(
          '  Acme Payroll  ',
          companyAddress: '  1 Main Street  ',
          gstin: '   ',
          businessRegistrationUrl: ' https://example.com/registration ',
          identityProofUrl: '',
        );

    expect(capturedBody, {
      'companyName': 'Acme Payroll',
      'companyAddress': '1 Main Street',
      'businessRegistrationUrl': 'https://example.com/registration',
    });
  });

  test('preserves typed backend error details', () async {
    final auth = _FakeAuthProvider();
    final client = MockClient(
      (_) async => _jsonResponse({
        'error': {
          'code': 'OWNER_REQUEST_EXISTS',
          'message': 'A pending ownership request already exists.',
        },
      }, 409),
    );
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(provider).requestOwnership('Acme Payroll'),
      throwsA(
        isA<CompanyApiException>()
            .having((error) => error.code, 'code', 'OWNER_REQUEST_EXISTS')
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.message,
              'message',
              'A pending ownership request already exists.',
            ),
      ),
    );
  });

  test('refreshes once and retries once after unauthorized response', () async {
    final auth = _FakeAuthProvider()..refreshResult = true;
    final authorizationHeaders = <String?>[];
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      authorizationHeaders.add(request.headers['authorization']);
      return _jsonResponse({
        'error': {'code': 'UNAUTHORIZED', 'message': 'Unauthorized'},
      }, 401);
    });
    final provider = _companyProviderFor(client);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(provider).getMyOwnerRequest(),
      throwsA(
        isA<CompanyApiException>()
            .having((error) => error.code, 'code', 'UNAUTHORIZED')
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );

    expect(requestCount, 2);
    expect(auth.refreshCalls, 1);
    expect(authorizationHeaders, [
      'Bearer access-token',
      'Bearer refreshed-token',
    ]);
  });
}
