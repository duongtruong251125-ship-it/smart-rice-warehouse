import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';

/// Strictly decodes public profile rows returned by Supabase PostgREST.
/// Invalid roles and active flags map to auth diagnostics and fail closed.
abstract final class SupabaseUserProfileCodec {
  static UserModel fromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final displayName = row['display_name'];
    final email = row['email'];
    final role = row['role'];
    final isActive = row['is_active'];

    if (id is! String || id.trim().isEmpty) {
      throw const RepositoryException('Hồ sơ Supabase không hợp lệ.',
          code: 'invalid-profile-data');
    }
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const RepositoryException('Hồ sơ Supabase không hợp lệ.',
          code: 'invalid-profile-data');
    }
    if (email is! String || email.trim().isEmpty) {
      throw const RepositoryException('Hồ sơ Supabase không hợp lệ.',
          code: 'invalid-profile-data');
    }
    if (role is! String || (role != 'admin' && role != 'staff')) {
      throw const RepositoryException('Hồ sơ phân quyền không hợp lệ.',
          code: 'invalid-profile-role');
    }
    if (isActive is! bool) {
      throw const RepositoryException('Dữ liệu hồ sơ tài khoản không hợp lệ.',
          code: 'invalid-profile-data');
    }

    final avatarPath = row['avatar_path'];
    if (avatarPath != null && avatarPath is! String) {
      throw const RepositoryException('Dữ liệu hồ sơ tài khoản không hợp lệ.',
          code: 'invalid-profile-data');
    }

    return UserModel(
      id: id,
      name: displayName.trim(),
      email: email.trim().toLowerCase(),
      role: role,
      isActive: isActive,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      avatarPath: avatarPath as String?,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const RepositoryException('Dữ liệu hồ sơ tài khoản không hợp lệ.',
          code: 'invalid-profile-data');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const RepositoryException('Dữ liệu hồ sơ tài khoản không hợp lệ.',
          code: 'invalid-profile-data');
    }
    return parsed;
  }
}
