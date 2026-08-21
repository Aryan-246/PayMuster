import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/sites/data/site_api.dart';
import 'package:paymuster_mobile/features/sites/presentation/sites_screen.dart';

Map<String, dynamic> _siteJson() {
  return {
    'id': 'site-1',
    'publicId': 'SITE-0001',
    'name': 'North Tower',
    'address': '12 Project Road',
    'status': 'ACTIVE',
    'startDate': '2026-07-01T00:00:00.000Z',
    'expectedEndDate': '2027-01-31T00:00:00.000Z',
    'workerCount': 1,
    'manager': {
      'id': 'manager-user-1',
      'firstName': 'Meera',
      'lastName': 'Patel',
    },
    'supervisor': {
      'id': 'supervisor-user-1',
      'firstName': 'Arun',
      'lastName': 'Singh',
    },
    'workers': [
      {
        'id': 'staff-1',
        'publicId': 'STF-0001',
        'firstName': 'Ravi',
        'lastName': 'Kumar',
        'workerType': 'FULL_TIME',
        'status': 'ACTIVE',
      },
    ],
    'approvedExpenseTotal': '1250.50',
  };
}

Widget _screenWith(List<SiteSummary> sites) {
  return ProviderScope(
    overrides: [sitesProvider.overrideWith((ref) async => sites)],
    child: const MaterialApp(home: SitesScreen()),
  );
}

void main() {
  group('SiteSummary.fromJson', () {
    test('keeps SiteMember people separate from assigned Staff workers', () {
      final site = SiteSummary.fromJson(_siteJson());

      expect(site.manager?.id, 'manager-user-1');
      expect(site.manager?.displayName, 'Meera Patel');
      expect(site.supervisor?.id, 'supervisor-user-1');
      expect(site.supervisor?.displayName, 'Arun Singh');
      expect(site.workers, hasLength(1));
      expect(site.workers.single.id, 'staff-1');
      expect(site.workers.single.publicId, 'STF-0001');
      expect(site.workers.single.displayName, 'Ravi Kumar');
      expect(site.approvedExpenseTotal, 1250.50);
    });

    test('rejects malformed worker relations with a typed response error', () {
      final json = _siteJson()..['workers'] = {'id': 'staff-1'};

      expect(
        () => SiteSummary.fromJson(json),
        throwsA(
          isA<TenantApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
    });
  });

  group('SitesScreen', () {
    testWidgets('renders management identities apart from assigned workers', (
      tester,
    ) async {
      final site = SiteSummary.fromJson(_siteJson());
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_screenWith([site]));
      await tester.pumpAndSettle();

      expect(find.text('North Tower'), findsOneWidget);
      expect(find.text('Meera Patel'), findsOneWidget);
      expect(find.text('Arun Singh'), findsOneWidget);
      expect(find.text('INR 1250.50'), findsNWidgets(2));
      expect(find.text('Add Site'), findsNothing);

      await tester.tap(find.byTooltip('Show assigned workers'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned workers'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('STF-0001  |  Full Time'), findsOneWidget);
      expect(find.text('Meera Patel'), findsOneWidget);
      expect(find.text('Arun Singh'), findsOneWidget);
    });
  });
}
