/// Mirrors the `Role` enum in the Prisma schema.
enum UserRole {
  customer,
  admin;

  static UserRole fromJson(String value) => switch (value.toUpperCase()) {
    'ADMIN' => UserRole.admin,
    _ => UserRole.customer,
  };
}

/// The signed-in customer, as returned by `GET /auth/me` and the auth endpoints.
final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    role: UserRole.fromJson(json['role'] as String),
  );

  final String id;
  final String email;
  final String name;
  final UserRole role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.name == name &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, email, name, role);

  @override
  String toString() => 'AuthUser(id: $id, email: $email, role: ${role.name})';
}
