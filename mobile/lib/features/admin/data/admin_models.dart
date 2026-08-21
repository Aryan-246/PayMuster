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
