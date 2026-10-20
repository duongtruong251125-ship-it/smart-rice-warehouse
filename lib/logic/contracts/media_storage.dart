abstract interface class MediaStorage {
  Future<String?> saveImagePermanently(
    String? sourcePath, {
    required String subDirectory,
    String? oldPathToDelete,
  });

  Future<bool> deleteImageIfExists(String? path);
}
