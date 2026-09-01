import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/features/company/data/membership_api.dart';

void main() {
  group('UserCompanies.fromJson', () {
    test('flag OFF parses honestly with an empty switchable list', () {
      final companies = UserCompanies.fromJson({
        'multiCompanyEnabled': false,
        'primary': {
          'orgId': 'org-1',
          'name': 'Primary Co',
          'publicId': 'PRI',
        },
        'memberships': <dynamic>[],
      });

      expect(companies.multiCompanyEnabled, isFalse);
      expect(companies.primary?.orgId, 'org-1');
      expect(companies.primary?.name, 'Primary Co');
      expect(companies.memberships, isEmpty);
    });

    test('flag ON parses active memberships alongside the primary org', () {
      final companies = UserCompanies.fromJson({
        'multiCompanyEnabled': true,
        'primary': {
          'orgId': 'org-1',
          'name': 'Primary Co',
          'publicId': 'PRI',
        },
        'memberships': [
          {
            'orgId': 'org-2',
            'name': 'Second Co',
            'publicId': 'SEC',
            'role': 'OWNER',
            'status': 'ACTIVE',
          },
        ],
      });

      expect(companies.multiCompanyEnabled, isTrue);
      expect(companies.memberships, hasLength(1));
      expect(companies.memberships.first.orgId, 'org-2');
      expect(companies.memberships.first.name, 'Second Co');
      expect(companies.memberships.first.role, 'OWNER');
    });

    test('missing optional fields never crash the parse', () {
      final companies = UserCompanies.fromJson({
        'multiCompanyEnabled': true,
        'primary': null,
        'memberships': [
          {'orgId': 'org-2', 'name': 'Second Co'},
        ],
      });

      expect(companies.primary, isNull);
      expect(companies.memberships, hasLength(1));
      expect(companies.memberships.first.publicId, isNull);
      expect(companies.memberships.first.role, '');
    });
  });
}
