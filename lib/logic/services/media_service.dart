import 'package:smart_rice_warehouse/logic/contracts/media_storage.dart';

/// Application entry point for persistent images, delegating to an injected [MediaStorage].
abstract final class MediaService {
  static MediaStorage? _storage;

  /// Injects or configures the underlying media storage implementation.
  static void initialize(MediaStorage storage) {
    _storage = storage;
  }

  static MediaStorage? get storage => _storage;

  static Future<String?> save(
    String? sourcePath, {
    required String subDirectory,
    String? oldPathToDelete,
  }) {
    if (_storage != null) {
      return _storage!.saveImagePermanently(
        sourcePath,
        subDirectory: subDirectory,
        oldPathToDelete: oldPathToDelete,
      );
    }
    return Future.value(sourcePath);
  }

  static Future<bool> delete(String? path) {
    if (_storage != null) {
      return _storage!.deleteImageIfExists(path);
    }
    return Future.value(false);
  }
}
