enum UserRole {
  owner,
  admin,
  supervisor,
  accountant,
  staff,
  superAdmin,
  viewer
}

class User {
  final String id;
  final String? publicId;
  final String email;
  final UserRole role;
  final String? organizationId;
  final String? name;

  const User({
    required this.id,
    this.publicId,
    required this.email,
    required this.role,
    this.organizationId,
    this.name,
  });

  User copyWith({
    String? id,
    String? publicId,
    String? email,
    UserRole? role,
    String? organizationId,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final roleValue = (json['role'] as String? ?? 'staff').toLowerCase();
    final role = switch (roleValue) {
      'superadmin' || 'super_admin' => UserRole.superAdmin,
      'owner' => UserRole.owner,
      'admin' => UserRole.admin,
      'supervisor' => UserRole.supervisor,
      'accountant' => UserRole.accountant,
      'viewer' => UserRole.viewer,
      _ => UserRole.staff,
    };

    return User(
      id: json['id'] as String,
      publicId: json['publicId'] as String?,
      email: json['email'] as String,
      role: role,
      organizationId: json['organizationId'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'publicId': publicId,
      'email': email,
      'role': role.name,
      'organizationId': organizationId,
      'name': name,
    };
  }
}
