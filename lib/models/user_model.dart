class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarPath;

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? avatarPath,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
