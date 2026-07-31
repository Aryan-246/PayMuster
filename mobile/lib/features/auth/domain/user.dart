class User {
  final String id;
  final String email;
  final String role;
  final String? organizationId;
  final String? name;

  const User({
    required this.id,
    required this.email,
    required this.role,
    this.organizationId,
    this.name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      organizationId: json['organizationId'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'organizationId': organizationId,
      'name': name,
    };
  }
}
