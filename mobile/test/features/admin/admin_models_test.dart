import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/features/admin/data/admin_models.dart';

void main() {
  group('AdminPayrollRecord.fromJson', () {
    Map<String, dynamic> payload(Object totalAmount) => {
      'id': 'pay-run-1',
      'publicId': 'PM-PR-000001',
      'totalAmount': totalAmount,
      'org': {'name': 'Example Company', 'publicId': 'PM-CMP-000001'},
      'payCycle': {
        'startDate': '2026-08-01',
        'endDate': '2026-08-15',
        'status': 'CALCULATED',
      },
      '_count': {'payRunItems': 2},
    };

    test('parses numeric decimal payloads', () {
      final record = AdminPayrollRecord.fromJson(payload(15000));

      expect(record.totalAmount, 15000.0);
    });

    test('parses string decimal payloads from serialized Decimal values', () {
      final record = AdminPayrollRecord.fromJson(payload('15000'));

      expect(record.totalAmount, 15000.0);
    });

    test('defaults malformed amounts to zero', () {
      final record = AdminPayrollRecord.fromJson(payload('not-a-number'));

      expect(record.totalAmount, 0.0);
    });
  });
}
