import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Dịch vụ quản lý lưu trữ hình ảnh vĩnh viễn trên thiết bị (Local Persistent Storage)
/// Giải quyết triệt để vấn đề mất ảnh do OS dọn dẹp thư mục tạm (Cache/Temp),
/// và tự động dọn dẹp các ảnh cũ để tối ưu dung lượng bộ nhớ.
abstract final class ImageStorageService {
  static const String _appFolder = 'smart_rice_warehouse';

  /// Lưu file ảnh vĩnh viễn vào thư mục Documents của ứng dụng
  /// [sourcePath]: Đường dẫn file nguồn (từ ImagePicker hoặc bộ nhớ tạm)
  /// [subDirectory]: Thư mục con phân loại ('avatars', 'damage_reports', v.v.)
  /// [oldPathToDelete]: Đường dẫn ảnh cũ cần xóa khi người dùng thay mới (ví dụ thay avatar)
  /// Trả về đường dẫn vĩnh viễn mới được lưu trên máy.
  static Future<String?> saveImagePermanently(
    String? sourcePath, {
    required String subDirectory,
    String? oldPathToDelete,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return null;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDirectory =
          Directory('${appDocDir.path}/$_appFolder/$subDirectory');
      if (!targetDirectory.existsSync()) {
        await targetDirectory.create(recursive: true);
      }

      // Đặt tên file duy nhất theo timestamp và thư mục con
      final extension = sourcePath.contains('.')
          ? sourcePath.substring(sourcePath.lastIndexOf('.'))
          : '.jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${subDirectory}_$timestamp$extension';
      final newFilePath = '${targetDirectory.path}/$newFileName';

      // Sao chép an toàn sang thư mục vĩnh viễn
      final savedFile = await sourceFile.copy(newFilePath);

      // Nếu có ảnh cũ và khác ảnh mới -> Xóa file ảnh cũ để tránh rác bộ nhớ máy
      if (oldPathToDelete != null &&
          oldPathToDelete.isNotEmpty &&
          oldPathToDelete != savedFile.path) {
        await deleteImageIfExists(oldPathToDelete);
      }

      return savedFile.path;
    } catch (e) {
      debugPrint('ImageStorageService error: $e');
      // Fallback về đường dẫn gốc nếu gặp sự cố sao chép
      return sourcePath;
    }
  }

  /// Xóa file ảnh cũ nếu tồn tại
  static Future<bool> deleteImageIfExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('assets/')) return false;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('deleteImageIfExists error: $e');
    }
    return false;
  }
}
