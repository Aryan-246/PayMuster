import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

/// Roster row from GET /api/v1/staff — the view_staff audience shape.
/// Financial PII (bank account, IFSC, UPI) is deliberately NOT part of this
/// model; it only ever arrives via [StaffProfile] from the manage_staff-gated
/// profile endpoint.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.publicId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    required this.workerType,
    required this.status,
    this.joinDate,
  });

  final String id;
  final String publicId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String workerType;
  final String status;
  final DateTime? joinDate;

  String get fullName => '$firstName $lastName';

  bool get isActive => status == 'ACTIVE';

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: _requiredString(json, 'id'),
      publicId: json['publicId'] as String? ?? '',
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      phone: _optionalString(json['phone']),
      email: _optionalString(json['email']),
      workerType: json['workerType'] as String? ?? 'DAILY',
      status: json['status'] as String? ?? 'ACTIVE',
      joinDate: _optionalDate(json['joinDate']),
    );
  }
}

class StaffPage {
  const StaffPage({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<StaffMember> items;
  final int total;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class StaffVerification {
  const StaffVerification({
    required this.bankDetailsComplete,
    required this.documentApproved,
    required this.verified,
  });

  final bool bankDetailsComplete;
  final bool documentApproved;
  final bool verified;

  factory StaffVerification.fromJson(Map<String, dynamic> json) {
    return StaffVerification(
      bankDetailsComplete: json['bankDetailsComplete'] == true,
      documentApproved: json['documentApproved'] == true,
      verified: json['verified'] == true,
    );
  }
}

class SalaryRule {
  const SalaryRule({
    required this.id,
    required this.rateType,
    required this.amount,
    required this.effectiveDate,
  });

  final String id;
  final String rateType;
  final String amount;
  final DateTime effectiveDate;

  factory SalaryRule.fromJson(Map<String, dynamic> json) {
    return SalaryRule(
      id: _requiredString(json, 'id'),
      rateType: json['rateType'] as String? ?? 'CUSTOM',
      amount: _decimalString(json['amount']),
      effectiveDate: _optionalDate(json['effectiveDate']) ?? DateTime(1970),
    );
  }
}

class StaffPayment {
  const StaffPayment({
    required this.id,
    required this.amount,
    required this.mode,
    required this.status,
    this.referenceId,
    this.approvedAt,
    required this.createdAt,
  });

  final String id;
  final String amount;
  final String mode;
  final String status;
  final String? referenceId;
  final DateTime? approvedAt;
  final DateTime createdAt;

  factory StaffPayment.fromJson(Map<String, dynamic> json) {
    return StaffPayment(
      id: _requiredString(json, 'id'),
      amount: _decimalString(json['amount']),
      mode: json['mode'] as String? ?? 'CASH',
      status: json['status'] as String? ?? 'DRAFT',
      referenceId: _optionalString(json['referenceId']),
      approvedAt: _optionalDate(json['approvedAt']),
      createdAt: _optionalDate(json['createdAt']) ?? DateTime(1970),
    );
  }
}

class StaffDocument {
  const StaffDocument({
    required this.id,
    required this.type,
    required this.status,
    this.expiryDate,
    required this.version,
    required this.resubmissionCount,
    this.reviewedAt,
    this.rejectionReason,
    this.originalFilename,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String status;
  final DateTime? expiryDate;
  final int version;
  final int resubmissionCount;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? originalFilename;
  final DateTime createdAt;

  bool get isPending =>
      status == 'PENDING' || status == 'PENDING_REVIEW' ||
      status == 'UPLOADED' || status == 'UNDER_REVIEW';
  bool get isApproved => status == 'APPROVED' || status == 'VERIFIED';

  factory StaffDocument.fromJson(Map<String, dynamic> json) {
    return StaffDocument(
      id: _requiredString(json, 'id'),
      type: json['type'] as String? ?? 'DOCUMENT',
      status: json['status'] as String? ?? 'PENDING',
      expiryDate: _optionalDate(json['expiryDate']),
      version: json['version'] is int ? json['version'] as int : 1,
      resubmissionCount:
          json['resubmissionCount'] is int ? json['resubmissionCount'] as int : 0,
      reviewedAt: _optionalDate(json['reviewedAt']),
      rejectionReason: _optionalString(json['rejectionReason']),
      originalFilename: _optionalString(json['originalFilename']),
      createdAt: _optionalDate(json['createdAt']) ?? DateTime(1970),
    );
  }
}

class StaffSiteAssignment {
  const StaffSiteAssignment({
    required this.id,
    required this.assignedAt,
    required this.siteId,
    required this.siteName,
    this.sitePublicId,
  });

  final String id;
  final DateTime assignedAt;
  final String siteId;
  final String siteName;
  final String? sitePublicId;

  factory StaffSiteAssignment.fromJson(Map<String, dynamic> json) {
    final site = json['site'];
    return StaffSiteAssignment(
      id: _requiredString(json, 'id'),
      assignedAt: _optionalDate(json['assignedAt']) ?? DateTime(1970),
      siteId: site is Map<String, dynamic> ? _requiredString(site, 'id') : '',
      siteName: site is Map<String, dynamic>
          ? (site['name'] as String? ?? '')
          : '',
      sitePublicId: site is Map<String, dynamic>
          ? _optionalString(site['publicId'])
          : null,
    );
  }
}

/// Enriched Owner/ADMIN read from GET /api/v1/staff/:id/profile
/// (manage_staff-gated). This is the only place bank details appear.
class StaffProfile {
  const StaffProfile({
    required this.member,
    required this.verification,
    required this.salaryRules,
    required this.documents,
    required this.siteAssignments,
    required this.payments,
    this.bankAccountNumber,
    this.ifscCode,
    this.upiId,
    this.preferredPaymentMethod,
  });

  final StaffMember member;
  final StaffVerification verification;
  final List<SalaryRule> salaryRules;
  final List<StaffDocument> documents;
  final List<StaffSiteAssignment> siteAssignments;
  final List<StaffPayment> payments;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? preferredPaymentMethod;

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final verification = json['verification'];
    return StaffProfile(
      member: StaffMember.fromJson(json),
      verification: verification is Map<String, dynamic>
          ? StaffVerification.fromJson(verification)
          : const StaffVerification(
              bankDetailsComplete: false,
              documentApproved: false,
              verified: false,
            ),
      salaryRules: _listOf(json['salaryRules'], SalaryRule.fromJson),
      documents: _listOf(json['documents'], StaffDocument.fromJson),
      siteAssignments: _listOf(
        json['siteAssignments'],
        StaffSiteAssignment.fromJson,
      ),
      payments: _listOf(json['payments'], StaffPayment.fromJson),
      bankAccountNumber: _optionalString(json['bankAccountNumber']),
      ifscCode: _optionalString(json['ifscCode']),
      upiId: _optionalString(json['upiId']),
      preferredPaymentMethod: _optionalString(json['preferredPaymentMethod']),
    );
  }
}

class CreateStaffInput {
  const CreateStaffInput({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.workerType,
    this.bankAccountNumber,
    this.ifscCode,
    this.upiId,
    this.preferredPaymentMethod,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String workerType;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? preferredPaymentMethod;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      if (email != null) 'email': email,
      'workerType': workerType,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (ifscCode != null) 'ifscCode': ifscCode,
      if (upiId != null) 'upiId': upiId,
      if (preferredPaymentMethod != null)
        'preferredPaymentMethod': preferredPaymentMethod,
    };
  }
}

/// Owner-facing staff directory client. Every call goes through
/// [TenantApiClient] so auth refresh, tenant headers and error envelopes are
/// handled uniformly; permissions (view_staff / manage_staff /
/// manage_documents) are enforced server-side.
class StaffDirectoryApi {
  const StaffDirectoryApi(this._client);

  final TenantApiClient _client;

  Future<StaffPage> listStaff({
    String? search,
    String? status,
    String? workerType,
    int page = 1,
    int limit = 25,
  }) async {
    final envelope = await _client.getWithMeta(
      '/staff',
      query: {
        'page': '$page',
        'limit': '$limit',
        'search': search,
        'status': status,
        'workerType': workerType,
      },
    );
    final rows = envelope.data;
    if (rows is! List) {
      throw const TenantApiException(
        'The server returned invalid staff data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return StaffPage(
      items: rows
          .map((item) => StaffMember.fromJson(_map(item, 'staff')))
          .toList(growable: false),
      total: envelope.intMeta('total') ?? 0,
      page: envelope.intMeta('page') ?? page,
      totalPages: envelope.intMeta('totalPages') ?? 0,
    );
  }

  Future<StaffProfile> getProfile(String staffId) async {
    final data = await _client.get('/staff/$staffId/profile');
    return StaffProfile.fromJson(_map(data, 'staff profile'));
  }

  Future<StaffMember> createStaff(CreateStaffInput input) async {
    final data = await _client.post('/staff', body: input.toJson());
    return StaffMember.fromJson(_map(data, 'staff'));
  }

  Future<List<StaffDocument>> listDocuments(String staffId) async {
    final data = await _client.get('/staff/$staffId/documents');
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid document data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .map((item) => StaffDocument.fromJson(_map(item, 'document')))
        .toList(growable: false);
  }

  /// [action] is APPROVED, REJECTED or VERIFIED. A REJECTED review must carry
  /// a reason — the schema validation on the server enforces it too.
  Future<void> reviewDocument(
    String staffId,
    String documentId,
    String action, {
    String? reason,
  }) async {
    await _client.post(
      '/staff/$staffId/documents/$documentId/review',
      body: {'action': action, 'reason': ?reason},
    );
  }
}

final staffDirectoryApiProvider = Provider<StaffDirectoryApi>((ref) {
  return StaffDirectoryApi(ref.watch(tenantApiClientProvider));
});

// ---------------------------------------------------------------------------
// JSON helpers (tolerant of nullable backend fields, strict about required
// ones so a contract drift fails loudly instead of rendering blank rows).
// ---------------------------------------------------------------------------

Map<String, dynamic> _map(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The server response is missing $field.',
    code: 'INVALID_RESPONSE',
  );
}

String? _optionalString(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _optionalDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _decimalString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  return '0';
}

List<T> _listOf<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}
