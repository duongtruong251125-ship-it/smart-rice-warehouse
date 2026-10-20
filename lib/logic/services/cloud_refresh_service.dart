import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';

/// Read-only refresh, not an upload of SQLite or an inventory migration.
class CloudRefreshService {
  const CloudRefreshService(
      {required this.authentication,
      required this.profiles,
      required this.refreshData});
  final AuthenticationService authentication;
  final UserProfileRepository profiles;
  final Future<void> Function() refreshData;

  Future<({bool success, String? message})> refresh() async {
    final user = authentication.currentUser;
    if (user == null) return (success: false, message: 'Vui lòng đăng nhập.');
    try {
      final profile = await profiles.getById(user.uid);
      if (profile == null ||
          profile.id != user.uid ||
          !profile.isActive ||
          !['admin', 'staff'].contains(profile.role) ||
          authentication.currentUser?.uid != user.uid) {
        return (success: false, message: 'Không có quyền tải dữ liệu cloud.');
      }
      await refreshData();
      if (authentication.currentUser?.uid != user.uid) {
        return (success: false, message: 'Phiên đăng nhập đã thay đổi.');
      }
      return (
        success: true,
        message:
            'Đã tải dữ liệu mới nhất từ máy chủ. Không upload dữ liệu SQLite.'
      );
    } catch (error) {
      return (success: false, message: 'Không thể tải dữ liệu cloud: $error');
    }
  }
}
