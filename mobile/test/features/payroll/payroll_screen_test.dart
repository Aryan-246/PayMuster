import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/payroll/data/payroll_api.dart';
import 'package:paymuster_mobile/features/payroll/presentation/payroll_screen.dart';

Map<String, dynamic> _payRunJson() {
  return {
    'id': 'run-1',
    'publicId': 'PAY-0001',
    'totalAmount': '47500.50',
    'createdAt': '2026-08-01T08:30:00.000Z',
    'updatedAt': '2026-08-02T09:45:00.000Z',
    'approvedAt': '2026-08-02T09:45:00.000Z',
    'approvedBy': {'id': 'user-1', 'firstName': 'Priya', 'lastName': 'Sharma'},
    'payCycle': {
      'id': 'cycle-1',
      'startDate': '2026-07-01T00:00:00.000Z',
      'endDate': '2026-07-31T00:00:00.000Z',
      'status': 'APPROVED',
    },
    'payRunItems': [
      {
        'id': 'item-1',
        'staffId': 'staff-1',
        'grossPay': '45000.50',
        'deductions': {'Tax': 2500},
        'additions': {'Safety allowance': '3000.00'},
        'arrears': {'Prior period': 2000},
        'netPay': '47500.50',
        'staff': {
          'id': 'staff-1',
          'publicId': 'STF-0001',
          'firstName': 'Ravi',
          'lastName': 'Kumar',
          'workerType': 'FULL_TIME',
          'status': 'ACTIVE',
        },
      },
    ],
  };
}

Widget _screenWith(List<PayRunSummary> runs) {
  return ProviderScope(
    overrides: [payRunsProvider.overrideWith((ref) async => runs)],
    child: const MaterialApp(home: PayrollScreen()),
  );
}

void main() {
  group('PayRunSummary.fromJson', () {
    test('parses supported payroll relations and Decimal strings', () {
      final run = PayRunSummary.fromJson(_payRunJson());

      expect(run.id, 'run-1');
      expect(run.publicId, 'PAY-0001');
      expect(run.totalAmount, 47500.50);
      expect(run.payCycle.status, 'APPROVED');
      expect(run.approvedBy?.displayName, 'Priya Sharma');
      expect(run.staffCount, 1);
      expect(run.items.single.staff.displayName, 'Ravi Kumar');
      expect(run.items.single.deductionTotal, 2500);
      expect(run.items.single.additionTotal, 3000);
      expect(run.items.single.arrearsTotal, 2000);
      expect(run.items.single.netPay, 47500.50);
    });

    test('rejects malformed adjustment maps with a typed response error', () {
      final json = _payRunJson();
      final item = (json['payRunItems'] as List).single as Map<String, dynamic>;
      item['deductions'] = ['Tax'];

      expect(
        () => PayRunSummary.fromJson(json),
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

  group('PayrollScreen', () {
    testWidgets('renders real pay run lifecycle and aggregate values', (
      tester,
    ) async {
      final run = PayRunSummary.fromJson(_payRunJson());
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_screenWith([run]));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('INR 47,500.50'), findsNWidgets(2));
      expect(find.text('1 staff entry'), findsOneWidget);
      expect(find.text('1 Jul 2026 - 31 Jul 2026'), findsOneWidget);
      expect(find.text('Run PAY-0001'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('By Priya Sharma'), findsOneWidget);
      expect(find.text('Process Run'), findsNothing);
      expect(find.textContaining('Disbursed'), findsNothing);
      expect(find.text('Paid'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('expands real staff monetary components', (tester) async {
      final run = PayRunSummary.fromJson(_payRunJson());
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_screenWith([run]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View staff details'));
      await tester.pumpAndSettle();

      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('STF-0001 | Full Time | Active'), findsOneWidget);
      expect(find.text('Gross'), findsOneWidget);
      expect(find.text('Additions'), findsOneWidget);
      expect(find.text('Arrears'), findsOneWidget);
      expect(find.text('Deductions'), findsOneWidget);
      expect(find.text('Addition: Safety allowance'), findsOneWidget);
      expect(find.text('Deduction: Tax'), findsOneWidget);
      expect(find.text('Arrears: Prior period'), findsOneWidget);
      expect(find.textContaining('Days'), findsNothing);
    });
  });
}
