import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';

/// Safe messages only: never include raw server errors or profile contents.
class AuthProfileDiagnostics {
  static const invalidRole =
      'Hồ sơ phân quyền không hợp lệ. Vui lòng liên hệ quản trị viên.';
  static const invalidData =
      'Dữ liệu hồ sơ tài khoản không hợp lệ. Vui lòng liên hệ quản trị viên.';

  static String? validate(UserModel? profile, String uid,
      {bool previouslyActive = false}) {
    if (profile == null) {
      return 'Không tìm thấy hồ sơ phân quyền. Vui lòng liên hệ quản trị viên.';
    }
    if (profile.id != uid) {
      return 'Hồ sơ tài khoản không khớp UID đăng nhập. Vui lòng liên hệ quản trị viên.';
    }
    if (!const ['admin', 'staff'].contains(profile.role)) return invalidRole;
    if (!profile.isActive) {
      return previouslyActive
          ? 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.'
          : 'Tài khoản chưa được kích hoạt hoặc đã bị khóa. Vui lòng liên hệ quản trị viên.';
    }
    return null;
  }

  static String readError(Object error) {
    final code = error is RepositoryException ? error.code : null;
    switch (code) {
      case 'invalid-profile-role':
        return invalidRole;
      case 'invalid-profile-data':
        return invalidData;
      case 'permission-denied':
        return 'Không có quyền đọc hồ sơ tài khoản. Vui lòng liên hệ quản trị viên.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Không thể tải hồ sơ do lỗi kết nối. Vui lòng kiểm tra mạng và thử lại.';
      case 'unverified-profile':
        return 'Chưa xác minh được hồ sơ từ máy chủ. Vui lòng thử lại.';
      default:
        return 'Không thể xác minh hồ sơ tài khoản. Vui lòng thử lại hoặc liên hệ quản trị viên.';
    }
  }
}
