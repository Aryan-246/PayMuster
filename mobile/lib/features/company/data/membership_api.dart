import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final membershipApiProvider = Provider<MembershipApi>((ref) {
  return MembershipApi(ref.read(tenantApiClientProvider));
});

/// One switchable company from GET /api/v1/company/memberships.
class MembershipCompany {
  const MembershipCompany({
    required this.orgId,
    required this.name,
    this.publicId,
    required this.role,
  });

  final String orgId;
  final String name;
  final String? publicId;
  final String role;

  factory MembershipCompany.fromJson(Map<String, dynamic> json) {
    return MembershipCompany(
      orgId: json['orgId'] as String,
      name: json['name'] as String,
      publicId: json['publicId'] as String?,
      role: json['role'] as String? ?? '',
    );
  }
}

class UserCompanies {
  const UserCompanies({
    required this.multiCompanyEnabled,
    required this.primary,
    required this.memberships,
  });

  final bool multiCompanyEnabled;
  final MembershipCompany? primary;
  final List<MembershipCompany> memberships;

  factory UserCompanies.fromJson(Map<String, dynamic> json) {
    final rawPrimary = json['primary'];
    final rawMemberships = json['memberships'];
    return UserCompanies(
      multiCompanyEnabled: json['multiCompanyEnabled'] as bool? ?? false,
      primary: rawPrimary is Map<String, dynamic>
          ? MembershipCompany.fromJson(rawPrimary)
          : null,
      memberships: rawMemberships is List
          ? rawMemberships
                .whereType<Map<String, dynamic>>()
                .map(MembershipCompany.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Multi-company read path (blueprint §L). With the feature flag OFF the
/// backend returns an honest empty list — callers render no switching UI.
class MembershipApi {
  const MembershipApi(this._client);

  final TenantApiClient _client;

  Future<UserCompanies> listUserCompanies() async {
    final data = await _client.getWithoutTenant('/company/memberships');
    if (data is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The company list could not be read.',
        code: 'INVALID_RESPONSE',
      );
    }
    return UserCompanies.fromJson(data);
  }
}
