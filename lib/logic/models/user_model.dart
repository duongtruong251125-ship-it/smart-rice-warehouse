class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? avatarPath;

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarPath,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
