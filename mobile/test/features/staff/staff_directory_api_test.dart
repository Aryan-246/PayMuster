import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/core/network/tenant_api_client.dart';
import 'package:paymuster_mobile/features/staff/data/staff_directory_api.dart';

void main() {
  group('StaffMember.fromJson', () {
    test('parses a roster row without any bank PII', () {
      final member = StaffMember.fromJson({
        'id': 'staff-1',
        'publicId': 'PM-STF-000001',
        'firstName': 'Ravi',
        'lastName': 'Kumar',
        'phone': '+919999999999',
        'workerType': 'DAILY',
        'status': 'ACTIVE',
        'joinDate': '2026-01-05T00:00:00.000Z',
      });

      expect(member.fullName, 'Ravi Kumar');
      expect(member.isActive, isTrue);
      expect(member.joinDate, isNotNull);
      // Bank fields are not even part of the roster model.
      expect(member.toString(), isNot(contains('bankAccountNumber')));
    });

    test('missing required id fails loudly instead of rendering a blank row', () {
      expect(
        () => StaffMember.fromJson({'firstName': 'Ravi', 'lastName': 'Kumar'}),
        throwsA(isA<TenantApiException>()),
      );
    });
  });

  group('StaffProfile.fromJson', () {
    test('parses verification, bank fields and nested lists', () {
      final profile = StaffProfile.fromJson({
        'id': 'staff-1',
        'publicId': 'PM-STF-000001',
        'firstName': 'Ravi',
        'lastName': 'Kumar',
        'workerType': 'DAILY',
        'status': 'ACTIVE',
        'verification': {
          'bankDetailsComplete': true,
          'documentApproved': true,
          'verified': true,
        },
        'bankAccountNumber': '1234567890',
        'ifscCode': 'HDFC0001234',
        'preferredPaymentMethod': 'BANK',
        'salaryRules': [
          {'id': 'rule-1', 'rateType': 'DAILY', 'amount': '750.00'},
        ],
        'documents': [
          {
            'id': 'doc-1',
            'type': 'AADHAAR',
            'status': 'APPROVED',
            'version': 2,
          },
          {
            'id': 'doc-2',
            'type': 'PAN',
            'status': 'PENDING_REVIEW',
            'version': 1,
          },
        ],
        'siteAssignments': [
          {
            'id': 'assign-1',
            'site': {'id': 'site-1', 'name': 'Mohali Tower A'},
          },
        ],
        'payments': [
          {
            'id': 'pay-1',
            'amount': 750,
            'mode': 'UPI',
            'status': 'PAID',
          },
        ],
      });

      expect(profile.verification.verified, isTrue);
      expect(profile.bankAccountNumber, '1234567890');
      expect(profile.ifscCode, 'HDFC0001234');
      expect(profile.salaryRules, hasLength(1));
      expect(profile.salaryRules.first.amount, '750.00');
      expect(profile.documents.first.isApproved, isTrue);
      expect(profile.documents.last.isPending, isTrue);
      expect(profile.siteAssignments.first.siteName, 'Mohali Tower A');
      expect(profile.payments.first.amount, '750');
      expect(profile.payments.first.status, 'PAID');
    });

    test('absent verification block defaults to unverified — never inferred', () {
      final profile = StaffProfile.fromJson({
        'id': 'staff-1',
        'publicId': 'PM-STF-000002',
        'firstName': 'Ashok',
        'lastName': 'Verma',
        'workerType': 'MONTHLY',
        'status': 'ACTIVE',
        'bankAccountNumber': '1234567890',
      });

      expect(profile.verification.verified, isFalse);
      expect(profile.verification.bankDetailsComplete, isFalse);
      expect(profile.documents, isEmpty);
      expect(profile.upiId, isNull);
    });
  });

  group('CreateStaffInput.toJson', () {
    test('omits unset optional fields so the strict server schema accepts it', () {
      final json = const CreateStaffInput(
        firstName: 'Ravi',
        lastName: 'Kumar',
        phone: '+919999999999',
        workerType: 'DAILY',
      ).toJson();

      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('bankAccountNumber'), isFalse);
      expect(json.containsKey('ifscCode'), isFalse);
      expect(json['workerType'], 'DAILY');
    });

    test('includes payment details when provided', () {
      final json = const CreateStaffInput(
        firstName: 'Ravi',
        lastName: 'Kumar',
        phone: '+919999999999',
        workerType: 'DAILY',
        bankAccountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        preferredPaymentMethod: 'BANK',
      ).toJson();

      expect(json['bankAccountNumber'], '1234567890');
      expect(json['ifscCode'], 'HDFC0001234');
      expect(json['preferredPaymentMethod'], 'BANK');
    });
  });
}
