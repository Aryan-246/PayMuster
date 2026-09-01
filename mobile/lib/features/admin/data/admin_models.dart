class AdminDashboardMetrics {
  final int users;
  final int owners;
  final int companies;
  final int sites;
  final int attendance;
  final int payroll;
  final int pendingRequests;
  final int onlineUsers;
  final int blockedUsers;
  final int deletedUsers;
  final List<AdminAuditLog> recentAuditLogs;

  const AdminDashboardMetrics({
    required this.users,
    required this.owners,
    required this.companies,
    required this.sites,
    required this.attendance,
    required this.payroll,
    required this.pendingRequests,
    required this.onlineUsers,
    required this.blockedUsers,
    required this.deletedUsers,
    this.recentAuditLogs = const [],
  });

  factory AdminDashboardMetrics.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['recentAuditLogs'] as List<dynamic>? ?? [];
    return AdminDashboardMetrics(
      users: (json['users'] as num?)?.toInt() ?? 0,
      owners: (json['owners'] as num?)?.toInt() ?? 0,
      companies: (json['companies'] as num?)?.toInt() ?? 0,
      sites: (json['sites'] as num?)?.toInt() ?? 0,
      attendance: (json['attendance'] as num?)?.toInt() ?? 0,
      payroll: (json['payroll'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      onlineUsers: (json['onlineUsers'] as num?)?.toInt() ?? 0,
      blockedUsers: (json['blockedUsers'] as num?)?.toInt() ?? 0,
      deletedUsers: (json['deletedUsers'] as num?)?.toInt() ?? 0,
      recentAuditLogs: rawLogs.map((l) => AdminAuditLog.fromJson(l)).toList(),
    );
  }
}

class AdminUser {
  final String id;
  final String publicId;
  final String email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String name;
  final String role;
  final String status;
  final bool isDisabled;
  final bool emailVerified;
  final String? createdAt;
  final String? lastLoginAt;
  final String? companyName;
  final String? companyPublicId;
  final String? companyId;

  const AdminUser({
    required this.id,
    required this.publicId,
    required this.email,
    this.phone,
    this.firstName,
    this.lastName,
    required this.name,
    required this.role,
    required this.status,
    required this.isDisabled,
    this.emailVerified = false,
    this.createdAt,
    this.lastLoginAt,
    this.companyName,
    this.companyPublicId,
    this.companyId,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final fname = json['firstName'] as String?;
    final lname = json['lastName'] as String?;
    final constructedName = [
      fname,
      lname,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final name = constructedName.isNotEmpty
        ? constructedName
        : (json['name'] as String? ??
              json['email'] as String? ??
              'Name unavailable');
    final org = json['org'] as Map<String, dynamic>?;

    return AdminUser(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      firstName: fname,
      lastName: lname,
      name: name,
      role: (json['role'] as String? ?? 'STAFF').toUpperCase(),
      status: json['status'] as String? ?? 'VERIFIED',
      isDisabled: json['isDisabled'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      lastLoginAt: json['lastLoginAt'] as String?,
      companyName: org?['name'] as String?,
      companyPublicId: org?['publicId'] as String?,
      companyId: org?['id'] as String?,
    );
  }
}

class AdminUserDetail {
  final AdminUser user;
  final List<AdminOwnerRequest> ownerRequests;
  final List<AdminAuditLog> auditLogs;
  final List<dynamic> documents;

  const AdminUserDetail({
    required this.user,
    this.ownerRequests = const [],
    this.auditLogs = const [],
    this.documents = const [],
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>? ?? json;
    final ownerReqs = (json['ownerRequests'] as List<dynamic>? ?? [])
        .map((r) => AdminOwnerRequest.fromJson(r))
        .toList();
    final logs = (json['auditLogs'] as List<dynamic>? ?? [])
        .map((l) => AdminAuditLog.fromJson(l))
        .toList();

    return AdminUserDetail(
      user: AdminUser.fromJson(userMap),
      ownerRequests: ownerReqs,
      auditLogs: logs,
      documents: json['documents'] as List<dynamic>? ?? [],
    );
  }
}

class AdminOwnerRequest {
  final String id;
  final String publicId;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final String userPublicId;
  final String companyName;
  final String? companyAddress;
  final String? gstin;
  final String status;
  final String? createdAt;
  final String? deleteReason;

  const AdminOwnerRequest({
    required this.id,
    required this.publicId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    required this.userPublicId,
    required this.companyName,
    this.companyAddress,
    this.gstin,
    required this.status,
    this.createdAt,
    this.deleteReason,
  });

  factory AdminOwnerRequest.fromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>? ?? {};
    final fname = u['firstName'] as String?;
    final lname = u['lastName'] as String?;
    final constructedName = [
      fname,
      lname,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final uname = constructedName.isNotEmpty
        ? constructedName
        : (u['email'] as String? ?? 'Name unavailable');

    return AdminOwnerRequest(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      userId: json['userId'] as String? ?? u['id'] as String? ?? '',
      userName: uname,
      userEmail: u['email'] as String? ?? '',
      userPhone: u['phone'] as String?,
      userPublicId: u['publicId'] as String? ?? 'Unavailable',
      companyName: json['companyName'] as String? ?? 'Name unavailable',
      companyAddress: json['companyAddress'] as String?,
      gstin: json['gstin'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] as String?,
      deleteReason: json['deleteReason'] as String?,
    );
  }
}

class AdminCompany {
  final String id;
  final String publicId;
  final String name;
  final String? joinCode;
  final String? gstin;
  final String status;
  final String? createdAt;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPublicId;
  final int userCount;
  final int siteCount;
  final int staffCount;

  const AdminCompany({
    required this.id,
    required this.publicId,
    required this.name,
    this.joinCode,
    this.gstin,
    required this.status,
    this.createdAt,
    this.ownerName,
    this.ownerEmail,
    this.ownerPublicId,
    required this.userCount,
    required this.siteCount,
    required this.staffCount,
  });

  factory AdminCompany.fromJson(Map<String, dynamic> json) {
    final users = (json['users'] as List<dynamic>? ?? []);
    final ownerMap = users.isNotEmpty
        ? users.first as Map<String, dynamic>
        : null;
    final counts = json['_count'] as Map<String, dynamic>? ?? {};

    return AdminCompany(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      name: json['name'] as String? ?? 'Name unavailable',
      joinCode: json['joinCode'] as String?,
      gstin: json['gstin'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] as String?,
      ownerName: ownerMap != null
          ? ([ownerMap['firstName'], ownerMap['lastName']]
                    .where((s) => s != null && (s as String).isNotEmpty)
                    .join(' ')
                    .trim()
                    .isNotEmpty
                ? [ownerMap['firstName'], ownerMap['lastName']]
                      .where((s) => s != null && (s as String).isNotEmpty)
                      .join(' ')
                : ownerMap['email'] as String?)
          : null,
      ownerEmail: ownerMap?['email'] as String?,
      ownerPublicId: ownerMap?['publicId'] as String?,
      userCount: (counts['users'] as num?)?.toInt() ?? 0,
      siteCount: (counts['sites'] as num?)?.toInt() ?? 0,
      staffCount: (counts['staff'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminSite {
  final String id;
  final String publicId;
  final String name;
  final String? address;
  final String status;
  final String? createdAt;
  final String? companyName;
  final String? companyPublicId;
  final int assignmentCount;
  final int attendanceCount;

  const AdminSite({
    required this.id,
    required this.publicId,
    required this.name,
    this.address,
    required this.status,
    this.createdAt,
    this.companyName,
    this.companyPublicId,
    required this.assignmentCount,
    required this.attendanceCount,
  });

  factory AdminSite.fromJson(Map<String, dynamic> json) {
    final org = json['org'] as Map<String, dynamic>?;
    final counts = json['_count'] as Map<String, dynamic>? ?? {};

    return AdminSite(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      name: json['name'] as String? ?? 'Name unavailable',
      address: json['address'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] as String?,
      companyName: org?['name'] as String?,
      companyPublicId: org?['publicId'] as String?,
      assignmentCount:
          (counts['siteAssignments'] as num?)?.toInt() ??
          (counts['siteMembers'] as num?)?.toInt() ??
          0,
      attendanceCount: (counts['attendanceRecords'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminAttendanceRecord {
  final String id;
  final String publicId;
  final String date;
  final String status;
  final String? checkInTime;
  final String? checkOutTime;
  final String staffName;
  final String? staffPublicId;
  final String siteName;
  final String companyName;

  const AdminAttendanceRecord({
    required this.id,
    required this.publicId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    required this.staffName,
    this.staffPublicId,
    required this.siteName,
    required this.companyName,
  });

  factory AdminAttendanceRecord.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] as Map<String, dynamic>? ?? {};
    final site = json['site'] as Map<String, dynamic>? ?? {};
    final org = json['org'] as Map<String, dynamic>? ?? {};
    final fname = staff['firstName'] as String?;
    final lname = staff['lastName'] as String?;
    final fullSname = [
      fname,
      lname,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final sname = fullSname.isNotEmpty
        ? fullSname
        : (staff['email'] as String? ?? 'Name unavailable');

    return AdminAttendanceRecord(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'PRESENT',
      checkInTime: json['checkInTime'] as String?,
      checkOutTime: json['checkOutTime'] as String?,
      staffName: sname,
      staffPublicId: staff['publicId'] as String?,
      siteName: site['name'] as String? ?? 'Name unavailable',
      companyName: org['name'] as String? ?? 'Name unavailable',
    );
  }
}

class AdminPayrollRecord {
  final String id;
  final String publicId;
  final double totalAmount;
  final String companyName;
  final String? companyPublicId;
  final String? startDate;
  final String? endDate;
  final String status;
  final int itemCount;
  final String? createdAt;

  const AdminPayrollRecord({
    required this.id,
    required this.publicId,
    required this.totalAmount,
    required this.companyName,
    this.companyPublicId,
    this.startDate,
    this.endDate,
    required this.status,
    required this.itemCount,
    this.createdAt,
  });

  factory AdminPayrollRecord.fromJson(Map<String, dynamic> json) {
    final org = json['org'] as Map<String, dynamic>? ?? {};
    final cycle = json['payCycle'] as Map<String, dynamic>? ?? {};
    final counts = json['_count'] as Map<String, dynamic>? ?? {};
    final rawTotalAmount = json['totalAmount'];
    final totalAmount = rawTotalAmount is num
        ? rawTotalAmount.toDouble()
        : double.tryParse(rawTotalAmount?.toString() ?? '') ?? 0.0;

    return AdminPayrollRecord(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? 'Unavailable',
      totalAmount: totalAmount,
      companyName: org['name'] as String? ?? 'Name unavailable',
      companyPublicId: org['publicId'] as String?,
      startDate: cycle['startDate'] as String?,
      endDate: cycle['endDate'] as String?,
      status: cycle['status'] as String? ?? 'CALCULATED',
      itemCount: (counts['payRunItems'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class AdminAuditLog {
  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String? userName;
  final String? userEmail;
  final String? userPublicId;
  final String? companyName;
  final Map<String, dynamic>? changes;
  final String createdAt;

  const AdminAuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.userName,
    this.userEmail,
    this.userPublicId,
    this.companyName,
    this.changes,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>?;
    final org = json['org'] as Map<String, dynamic>?;
    final fname = u?['firstName'] as String?;
    final lname = u?['lastName'] as String?;
    final fullUname = [
      fname,
      lname,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final uname = fullUname.isNotEmpty ? fullUname : u?['email'] as String?;

    return AdminAuditLog(
      id: json['id'] as String,
      action: json['action'] as String? ?? 'UPDATE',
      entityType: json['entityType'] as String? ?? 'System',
      entityId: json['entityId'] as String? ?? '',
      userName: uname,
      userEmail: u?['email'] as String?,
      userPublicId: u?['publicId'] as String?,
      companyName: org?['name'] as String?,
      changes: json['changes'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AdminNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? userName;
  final String? companyName;
  final String createdAt;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.userName,
    this.companyName,
    required this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    final u = json['user'] as Map<String, dynamic>?;
    final org = json['org'] as Map<String, dynamic>?;

    return AdminNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'SYSTEM',
      userName: u?['email'] as String?,
      companyName: org?['name'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AnnouncementDispatchRequest {
  const AnnouncementDispatchRequest({
    required this.title,
    required this.body,
    required this.type,
    required this.audience,
    this.orgId,
    this.audienceRole,
    this.audienceUserId,
    this.deepLink,
  });

  final String title;
  final String body;
  final String type;
  final String audience;
  final String? orgId;
  final String? audienceRole;
  final String? audienceUserId;
  final String? deepLink;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'type': type,
    'audience': audience,
    if (orgId != null && orgId!.trim().isNotEmpty) 'orgId': orgId!.trim(),
    if (audienceRole != null && audienceRole!.trim().isNotEmpty)
      'audienceRole': audienceRole!.trim(),
    if (audienceUserId != null && audienceUserId!.trim().isNotEmpty)
      'audienceUserId': audienceUserId!.trim(),
    if (deepLink != null && deepLink!.trim().isNotEmpty)
      'deepLink': deepLink!.trim(),
  };
}

class AnnouncementDispatchResult {
  const AnnouncementDispatchResult({
    required this.campaignId,
    required this.audience,
    required this.recipientCount,
    required this.createdAt,
    this.orgId,
  });

  final String campaignId;
  final String audience;
  final String? orgId;
  final int recipientCount;
  final DateTime createdAt;

  factory AnnouncementDispatchResult.fromJson(Map<String, dynamic> json) {
    final recipientCount = json['recipientCount'];
    final parsedCreatedAt = DateTime.tryParse(
      json['createdAt']?.toString() ?? '',
    );
    if (json['campaignId'] is! String ||
        json['audience'] is! String ||
        recipientCount is! num ||
        parsedCreatedAt == null) {
      throw const FormatException('Invalid announcement dispatch response.');
    }

    return AnnouncementDispatchResult(
      campaignId: json['campaignId'] as String,
      audience: json['audience'] as String,
      orgId: json['orgId'] as String?,
      recipientCount: recipientCount.toInt(),
      createdAt: parsedCreatedAt,
    );
  }
}

/// Recipient preview for the single announcement compose workflow. The count
/// is server-derived from the exact same filter dispatch uses — never an
/// estimate — so the admin sees precisely who will be notified.
class AnnouncementPreview {
  const AnnouncementPreview({
    required this.audience,
    this.orgId,
    required this.recipientCount,
    required this.sampleRecipients,
  });

  final String audience;
  final String? orgId;
  final int recipientCount;
  final List<AnnouncementPreviewRecipient> sampleRecipients;

  factory AnnouncementPreview.fromJson(Map<String, dynamic> json) {
    return AnnouncementPreview(
      audience: json['audience'] as String? ?? '',
      orgId: json['orgId'] as String?,
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
      sampleRecipients: (json['sampleRecipients'] as List<dynamic>? ?? [])
          .map((r) => AnnouncementPreviewRecipient.fromJson(
              r as Map<String, dynamic>? ?? const {}))
          .toList(),
    );
  }
}

class AnnouncementPreviewRecipient {
  const AnnouncementPreviewRecipient({
    this.publicId,
    required this.name,
    this.email,
  });

  final String? publicId;
  final String name;
  final String? email;

  factory AnnouncementPreviewRecipient.fromJson(Map<String, dynamic> json) {
    return AnnouncementPreviewRecipient(
      publicId: json['publicId'] as String?,
      name: json['name'] as String? ?? 'Unnamed recipient',
      email: json['email'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Subscriptions administration
// ---------------------------------------------------------------------------

class AdminSubscriber {
  const AdminSubscriber({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.orgPublicId,
    this.ownerName,
    this.ownerPublicId,
    this.ownerRequestId,
    required this.planCode,
    required this.planName,
    this.planAmountMinor,
    this.planCurrency,
    required this.status,
    required this.provider,
    this.trialEndsAt,
    required this.cancelAtPeriodEnd,
    required this.unlimitedAccess,
    this.currentPeriodEnd,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String orgName;
  final String orgPublicId;
  final String? ownerName;
  final String? ownerPublicId;
  final String? ownerRequestId;
  final String planCode;
  final String planName;
  final String? planAmountMinor;
  final String? planCurrency;
  final String status;
  final String provider;
  final String? trialEndsAt;
  final bool cancelAtPeriodEnd;
  final bool unlimitedAccess;
  final String? currentPeriodEnd;
  final String? createdAt;

  bool get isTrialActive {
    final ends = DateTime.tryParse(trialEndsAt ?? '');
    return ends != null && ends.isAfter(DateTime.now());
  }

  /// True when the organization actually has a subscription row. Orgs with no
  /// subscription are listed with status NO_SUBSCRIPTION so the admin can
  /// still open their detail page and provision/grant access.
  bool get hasSubscription => id.isNotEmpty && status != 'NO_SUBSCRIPTION';

  bool get isPaid =>
      status == 'ACTIVE' && !isTrialActive && planAmountMinor != '0';

  factory AdminSubscriber.fromJson(Map<String, dynamic> json) {
    final org = json['org'] as Map<String, dynamic>? ?? {};
    final plan = json['plan'] as Map<String, dynamic>? ?? {};
    final owner = json['owner'] as Map<String, dynamic>?;
    String? ownerName;
    if (owner != null) {
      final joined = [
        owner['firstName'],
        owner['lastName'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
      ownerName = joined.isNotEmpty ? joined : owner['email'] as String?;
    }

    return AdminSubscriber(
      id: json['id'] as String? ?? '',
      orgId: json['orgId'] as String? ?? org['id'] as String? ?? '',
      orgName: org['name'] as String? ?? 'Name unavailable',
      orgPublicId: org['publicId'] as String? ?? 'Unavailable',
      ownerName: ownerName,
      ownerPublicId: owner?['publicId'] as String?,
      ownerRequestId: json['ownerRequestId'] as String?,
      planCode: plan['code'] as String? ?? 'NO PLAN',
      planName: plan['name'] as String? ?? 'No active plan',
      planAmountMinor: plan['amountMinor']?.toString(),
      planCurrency: plan['currency'] as String?,
      status: json['status'] as String? ?? 'TRIALING',
      provider: json['provider'] as String? ?? 'razorpay',
      trialEndsAt: json['trialEndsAt'] as String?,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      unlimitedAccess: json['unlimitedAccess'] as bool? ?? false,
      currentPeriodEnd: json['currentPeriodEnd'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class AdminSubscriptionsSummary {
  const AdminSubscriptionsSummary({
    required this.total,
    required this.activeCount,
    required this.trialCount,
    required this.unlimitedCount,
    required this.paidCount,
    this.noSubscriptionCount = 0,
  });

  final int total;
  final int activeCount;
  final int trialCount;
  final int unlimitedCount;
  final int paidCount;
  final int noSubscriptionCount;

  factory AdminSubscriptionsSummary.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionsSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      trialCount: (json['trialCount'] as num?)?.toInt() ?? 0,
      unlimitedCount: (json['unlimitedCount'] as num?)?.toInt() ?? 0,
      paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
      noSubscriptionCount: (json['noSubscriptionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminSubscriptionDetail {
  const AdminSubscriptionDetail({
    required this.subscription,
    required this.org,
    required this.owners,
    this.ownerRequestId,
    required this.history,
    required this.mailSentThisMonth,
    this.mailPeriodEnd,
    this.noSubscription = false,
    this.provisionable = false,
  });

  final Map<String, dynamic> subscription;
  final Map<String, dynamic>? org;
  final List<Map<String, dynamic>> owners;
  final String? ownerRequestId;
  final List<Map<String, dynamic>> history;
  final int mailSentThisMonth;
  final String? mailPeriodEnd;

  /// True when the organization has no subscription record. The detail page is
  /// still actionable: granting unlimited access provisions a subscription on
  /// the cheapest active plan first (server-side business rule).
  final bool noSubscription;
  final bool provisionable;

  factory AdminSubscriptionDetail.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionDetail(
      subscription: json['subscription'] as Map<String, dynamic>? ?? {},
      org: json['org'] as Map<String, dynamic>?,
      owners: (json['owners'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      ownerRequestId:
          (json['ownerRequest'] as Map<String, dynamic>?)?['publicId']
              as String?,
      history: (json['history'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      mailSentThisMonth:
          (((json['mailUsage'] as Map<String, dynamic>?)?['sentThisMonth'])
                  as num?)
              ?.toInt() ??
          0,
      mailPeriodEnd:
          (json['mailUsage'] as Map<String, dynamic>?)?['periodEnd'] as String?,
      noSubscription: json['noSubscription'] as bool? ??
          (json['subscription'] == null),
      provisionable: json['provisionable'] as bool? ?? false,
    );
  }
}

class AdminPlan {
  const AdminPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.interval,
    required this.trialDays,
  });

  final String id;
  final String code;
  final String name;
  final String amountMinor;
  final String currency;
  final String interval;
  final int trialDays;

  factory AdminPlan.fromJson(Map<String, dynamic> json) {
    return AdminPlan(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown plan',
      amountMinor: json['amountMinor']?.toString() ?? '0',
      currency: json['currency'] as String? ?? 'INR',
      interval: json['interval'] as String? ?? 'MONTH',
      trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Platform payments
// ---------------------------------------------------------------------------

class AdminPaymentEvent {
  const AdminPaymentEvent({
    required this.id,
    required this.provider,
    required this.providerEventId,
    required this.eventType,
    required this.status,
    required this.createdAt,
    this.failureReason,
    this.orgName,
    this.orgPublicId,
    this.subscriptionStatus,
    this.planCode,
  });

  final String id;
  final String provider;
  final String providerEventId;
  final String eventType;
  final String status;
  final String createdAt;
  final String? failureReason;
  final String? orgName;
  final String? orgPublicId;
  final String? subscriptionStatus;
  final String? planCode;

  factory AdminPaymentEvent.fromJson(Map<String, dynamic> json) {
    final org = json['org'] as Map<String, dynamic>?;
    final sub = json['subscription'] as Map<String, dynamic>?;

    return AdminPaymentEvent(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? 'razorpay',
      providerEventId: json['providerEventId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      status: json['status'] as String? ?? 'RECEIVED',
      createdAt: json['createdAt'] as String? ?? '',
      failureReason: json['failureReason'] as String?,
      orgName: org?['name'] as String?,
      orgPublicId: org?['publicId'] as String?,
      subscriptionStatus: sub?['status'] as String?,
      planCode: (sub?['plan'] as Map<String, dynamic>?)?['code'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Platform mail supply
// ---------------------------------------------------------------------------

class AdminMailDispatch {
  const AdminMailDispatch({
    required this.id,
    required this.subject,
    required this.targetType,
    required this.recipientCount,
    required this.sent,
    required this.failed,
    required this.status,
    required this.createdAt,
    this.orgName,
  });

  final String id;
  final String subject;
  final String targetType;
  final int recipientCount;
  final int sent;
  final int failed;
  final String status;
  final String createdAt;
  final String? orgName;

  factory AdminMailDispatch.fromJson(Map<String, dynamic> json) {
    final sent = (json['sent'] as num?)?.toInt() ?? 0;
    final failed = (json['failed'] as num?)?.toInt() ?? 0;
    return AdminMailDispatch(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Subject unavailable',
      targetType: json['targetType'] as String? ?? 'ALL',
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
      sent: sent,
      failed: failed,
      status: failed > 0 && sent > 0
          ? 'PARTIAL'
          : failed > 0
              ? 'FAILED'
              : sent > 0
                  ? 'SENT'
                  : (json['status'] as String? ?? 'PENDING'),
      createdAt: json['createdAt'] as String? ?? '',
      orgName: (json['org'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}

class AdminMailOverview {
  const AdminMailOverview({
    required this.totalDispatches,
    required this.totalSent,
    required this.totalFailed,
    required this.mailSentThisMonth,
    required this.orgsUsingMail,
    required this.orgCount,
    required this.userCount,
    required this.freePlanMonthlyLimit,
    required this.dispatches,
  });

  final int totalDispatches;
  final int totalSent;
  final int totalFailed;
  final int mailSentThisMonth;
  final int orgsUsingMail;
  final int orgCount;
  final int userCount;
  final int freePlanMonthlyLimit;
  final List<AdminMailDispatch> dispatches;

  factory AdminMailOverview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final quota = json['quota'] as Map<String, dynamic>? ?? {};
    final dispatches = (json['dispatches'] as List<dynamic>? ?? [])
        .map((d) => AdminMailDispatch.fromJson(d as Map<String, dynamic>))
        .toList();

    return AdminMailOverview(
      totalDispatches: (summary['totalDispatches'] as num?)?.toInt() ?? 0,
      totalSent: (summary['totalSent'] as num?)?.toInt() ?? 0,
      totalFailed: (summary['totalFailed'] as num?)?.toInt() ?? 0,
      mailSentThisMonth: (summary['mailSentThisMonth'] as num?)?.toInt() ?? 0,
      orgsUsingMail: (summary['orgsUsingMail'] as num?)?.toInt() ?? 0,
      orgCount: (summary['orgCount'] as num?)?.toInt() ?? 0,
      userCount: (summary['userCount'] as num?)?.toInt() ?? 0,
      freePlanMonthlyLimit:
          (quota['freePlanMonthlyLimit'] as num?)?.toInt() ?? 10,
      dispatches: dispatches,
    );
  }
}

class AdminMailPreviewResult {
  const AdminMailPreviewResult({required this.count, required this.quotaRemaining});

  final int count;
  final int quotaRemaining;

  factory AdminMailPreviewResult.fromJson(Map<String, dynamic> json) {
    return AdminMailPreviewResult(
      count: (json['count'] as num?)?.toInt() ?? 0,
      quotaRemaining: (json['quotaRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminMailSendResult {
  const AdminMailSendResult({
    required this.sent,
    required this.failed,
    required this.blocked,
    required this.dispatchId,
    this.duplicate,
    this.errors = const [],
  });

  final int sent;
  final int failed;
  final int blocked;
  final String dispatchId;
  final bool? duplicate;
  final List<Map<String, dynamic>> errors;

  String get outcome {
    if (duplicate == true) return 'DUPLICATE';
    if (sent > 0 && failed > 0) return 'PARTIAL';
    if (sent > 0) return 'SENT';
    if (failed > 0) return 'FAILED';
    return 'QUEUED';
  }

  factory AdminMailSendResult.fromJson(Map<String, dynamic> json) {
    return AdminMailSendResult(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      blocked: (json['blocked'] as num?)?.toInt() ?? 0,
      dispatchId: json['dispatchId'] as String? ?? '',
      duplicate: json['duplicate'] as bool?,
      errors: (json['errors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform announcements history
// ---------------------------------------------------------------------------

class AdminAnnouncementCampaign {
  const AdminAnnouncementCampaign({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.audience,
    required this.recipientCount,
    required this.createdAt,
    this.orgName,
    this.actorName,
    this.acknowledgementCount,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String audience;
  final int recipientCount;
  final String createdAt;
  final String? orgName;
  final String? actorName;
  final int? acknowledgementCount;

  factory AdminAnnouncementCampaign.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final actorName = actor == null
        ? null
        : [actor['firstName'], actor['lastName']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ')
            .trim();
    final counts = json['_count'] as Map<String, dynamic>?;

    return AdminAnnouncementCampaign(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Title unavailable',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'INFORMATION',
      audience: json['audience'] as String? ?? 'ORGANIZATION',
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
      orgName: (json['org'] as Map<String, dynamic>?)?['name'] as String?,
      actorName: actorName?.isNotEmpty == true ? actorName : actor?['email'] as String?,
      acknowledgementCount: (json['acknowledgementCount'] as num?)?.toInt() ??
          (counts?['notifications'] as num?)?.toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer Reviews
// ---------------------------------------------------------------------------

class AdminReview {
  const AdminReview({
    required this.id,
    required this.publicId,
    required this.rating,
    required this.text,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.moderatedAt,
    this.userName,
    this.userPublicId,
    this.userEmail,
    this.userRole,
    this.orgName,
    this.orgPublicId,
  });

  final String id;
  final String publicId;
  final int rating;
  final String text;
  final String status;
  final String createdAt;
  final String? adminResponse;
  final String? moderatedAt;
  final String? userName;
  final String? userPublicId;
  final String? userEmail;
  final String? userRole;
  final String? orgName;
  final String? orgPublicId;

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final org = json['org'] as Map<String, dynamic>? ?? {};
    final userName = [
      user['firstName'],
      user['lastName'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();

    return AdminReview(
      id: json['id'] as String? ?? '',
      publicId: json['publicId'] as String? ?? 'Unavailable',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] as String? ?? '',
      adminResponse: json['adminResponse'] as String?,
      moderatedAt: json['moderatedAt'] as String?,
      userName: userName.isNotEmpty ? userName : user['email'] as String?,
      userPublicId: user['publicId'] as String?,
      userEmail: user['email'] as String?,
      userRole: user['role'] as String?,
      orgName: org['name'] as String?,
      orgPublicId: org['publicId'] as String?,
    );
  }
}

class AdminReviewSummary {
  const AdminReviewSummary({
    required this.total,
    required this.average,
    required this.distribution,
    required this.pendingCount,
    required this.publishedCount,
    required this.hiddenCount,
    required this.flaggedCount,
  });

  final int total;
  final double average;
  final Map<int, int> distribution;
  final int pendingCount;
  final int publishedCount;
  final int hiddenCount;
  final int flaggedCount;

  factory AdminReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawDistribution = json['distribution'] as Map<String, dynamic>? ?? {};
    final distribution = <int, int>{};
    rawDistribution.forEach((key, value) {
      final star = int.tryParse(key);
      if (star != null && star >= 1 && star <= 5) {
        distribution[star] = (value as num?)?.toInt() ?? 0;
      }
    });

    return AdminReviewSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      distribution: distribution,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      publishedCount: (json['publishedCount'] as num?)?.toInt() ?? 0,
      hiddenCount: (json['hiddenCount'] as num?)?.toInt() ?? 0,
      flaggedCount: (json['flaggedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Reports / analytics
// ---------------------------------------------------------------------------

class AdminReportsOverview {
  const AdminReportsOverview({
    required this.totals,
    required this.series,
    required this.days,
  });

  final Map<String, int> totals;
  final Map<String, Map<String, int>> series;
  final List<String> days;

  factory AdminReportsOverview.fromJson(Map<String, dynamic> json) {
    final rawTotals = json['totals'] as Map<String, dynamic>? ?? {};
    final totals = rawTotals.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    final rawSeries = json['series'] as Map<String, dynamic>? ?? {};
    final series = <String, Map<String, int>>{};
    rawSeries.forEach((metric, rawDays) {
      final dayMap = <String, int>{};
      (rawDays as Map<String, dynamic>).forEach((day, count) {
        dayMap[day] = (count as num?)?.toInt() ?? 0;
      });
      series[metric] = dayMap;
    });

    final dayKeys = <String>{};
    for (final dayMap in series.values) {
      dayKeys.addAll(dayMap.keys);
    }
    final days = dayKeys.toList()..sort();

    return AdminReportsOverview(
      totals: totals,
      series: series,
      days: days,
    );
  }
}

// ---------------------------------------------------------------------------
// Owners
// ---------------------------------------------------------------------------

class AdminOwner {
  const AdminOwner({
    required this.id,
    required this.publicId,
    required this.name,
    required this.email,
    required this.status,
    required this.isDisabled,
    required this.createdAt,
    this.companyName,
    this.companyPublicId,
    this.companyId,
  });

  final String id;
  final String publicId;
  final String name;
  final String email;
  final String status;
  final bool isDisabled;
  final String createdAt;
  final String? companyName;
  final String? companyPublicId;
  final String? companyId;

  factory AdminOwner.fromJson(AdminUser user) {
    return AdminOwner(
      id: user.id,
      publicId: user.publicId,
      name: user.name,
      email: user.email,
      status: user.status,
      isDisabled: user.isDisabled,
      createdAt: user.createdAt ?? '',
      companyName: user.companyName,
      companyPublicId: user.companyPublicId,
      companyId: user.companyId,
    );
  }
}
