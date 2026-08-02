enum UserRole {
  superAdmin,
  companyOwner,
  siteManager,
  supervisor,
  worker
}

class User {
  final String id;
  final String email;
  final UserRole role;
  final String? organizationId;
  final String? name;

  const User({
    required this.id,
    required this.email,
    required this.role,
    this.organizationId,
    this.name,
  });

  User copyWith({
    String? id,
    String? email,
    UserRole? role,
    String? organizationId,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final roleValue = (json['role'] as String? ?? 'worker').toLowerCase();
    final role = switch (roleValue) {
      'superadmin' || 'admin' => UserRole.superAdmin,
      'companyowner' || 'owner' => UserRole.companyOwner,
      'sitemanager' || 'manager' => UserRole.siteManager,
      'supervisor' => UserRole.supervisor,
      _ => UserRole.worker,
    };

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: role,
      organizationId: json['organizationId'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'organizationId': organizationId,
      'name': name,
    };
  }
}
