import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

class ProfileViewModel {
  Future<({bool success, String? message})> save({
    required AuthProvider auth,
    required String name,
    required UserModel? original,
    String? imagePath,
  }) async {
    if (name.trim().isEmpty) {
      return (success: false, message: 'Họ và tên không được để trống.');
    }
    var avatarPath = original?.avatarPath;
    if (imagePath != null) {
      avatarPath = await MediaService.save(imagePath,
          subDirectory: 'avatars', oldPathToDelete: original?.avatarPath);
    }
    return auth.updateProfileWithFirebase(
        name: name.trim(), avatarPath: avatarPath);
  }

  static WarehouseSyncStatus resolveSyncStatus({
    RiceProvider? rices,
    BatchProvider? batches,
    ImportProvider? imports,
    ExportProvider? exports,
    bool? backgroundSyncEnabled,
  }) {
    final sources = <SyncSourceSnapshot>[
      if (rices != null)
        SyncSourceSnapshot(
          usesFirestore: rices.usesFirestore,
          isLoading: rices.isLoading,
          errorMessage: rices.errorMessage,
        ),
      if (batches != null)
        SyncSourceSnapshot(
          usesFirestore: batches.usesFirestore,
          isLoading: batches.isLoading,
          errorMessage: batches.errorMessage,
        ),
      if (imports != null)
        SyncSourceSnapshot(
          usesFirestore: imports.usesFirestore,
          isLoading: imports.isLoading,
          errorMessage: imports.errorMessage,
        ),
      if (exports != null)
        SyncSourceSnapshot(
          usesFirestore: exports.usesFirestore,
          isLoading: exports.isLoading,
          errorMessage: exports.errorMessage,
        ),
    ];
    return WarehouseSyncStatus.resolve(
      sources: sources,
      backgroundSyncEnabled: backgroundSyncEnabled,
    );
  }

  static void retrySync({
    RiceProvider? rices,
    BatchProvider? batches,
    ImportProvider? imports,
    ExportProvider? exports,
  }) {
    rices?.retrySync();
    batches?.retrySync();
    imports?.retrySync();
    exports?.retrySync();
  }
}
