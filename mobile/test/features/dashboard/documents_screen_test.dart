import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/features/auth/domain/auth_state.dart';
import 'package:paymuster_mobile/features/auth/domain/user.dart';
import 'package:paymuster_mobile/features/auth/presentation/auth_controller.dart';
import 'package:paymuster_mobile/features/dashboard/data/document_api_client.dart';
import 'package:paymuster_mobile/features/dashboard/presentation/documents_screen.dart';

class _TestAuthController extends AuthController {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      isInitializing: false,
      hasSeenOnboarding: true,
      user: User(
        id: 'user-1',
        email: 'worker@example.com',
        role: UserRole.staff,
        name: 'Worker',
      ),
    );
  }
}

class _FakeDocumentApiClient extends DocumentApiClient {
  _FakeDocumentApiClient(super.ref, {this.documents, this.failure});

  final List<StaffDocumentSummary>? documents;
  final Object? failure;

  @override
  Future<List<StaffDocumentSummary>> listMine() async {
    if (failure != null) throw failure!;
    return documents ?? const [];
  }
}

StaffDocumentSummary _document({String status = 'PENDING_REVIEW'}) {
  final timestamp = DateTime.utc(2026, 8, 17);
  return StaffDocumentSummary(
    id: 'document-1',
    type: 'Identity proof',
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Widget _buildScreen({List<StaffDocumentSummary>? documents, Object? failure}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_TestAuthController.new),
      documentApiClientProvider.overrideWith(
        (ref) =>
            _FakeDocumentApiClient(ref, documents: documents, failure: failure),
      ),
    ],
    child: MaterialApp(home: const DocumentsScreen()),
  );
}

void main() {
  group('StaffDocumentSummary.fromJson', () {
    test('parses document metadata without a storage path', () {
      final document = StaffDocumentSummary.fromJson({
        'id': 'document-1',
        'type': 'Identity proof',
        'status': 'VERIFIED',
        'expiryDate': '2027-01-10T00:00:00.000Z',
        'createdAt': '2026-08-17T00:00:00.000Z',
        'updatedAt': '2026-08-18T00:00:00.000Z',
      });

      expect(document.id, 'document-1');
      expect(document.type, 'Identity proof');
      expect(document.status, 'VERIFIED');
      expect(document.expiryDate, DateTime.utc(2027, 1, 10));
    });
  });

  group('DocumentsScreen', () {
    testWidgets(
      'shows empty state when the authenticated user has no documents',
      (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('No documents yet'), findsOneWidget);
        expect(find.text('Upload document'), findsOneWidget);
        expect(find.text('Upload feature coming soon'), findsNothing);
      },
    );

    testWidgets('shows document status and metadata from the API', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(documents: [_document()]));
      await tester.pumpAndSettle();

      expect(find.text('Identity proof'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Submitted 2026-08-17  |  Version 1'), findsOneWidget);
    });

    testWidgets('shows a retryable error state when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(failure: Exception('Document service unavailable')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Documents unavailable'), findsOneWidget);
      expect(find.text('Document service unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
