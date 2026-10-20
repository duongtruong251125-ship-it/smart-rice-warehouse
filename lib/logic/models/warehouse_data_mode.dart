/// Explicit data ownership. Background refresh never selects a backend.
enum WarehouseDataMode {
  demo('smart_rice_warehouse_demo.db'),
  local('smart_rice_warehouse.db'),
  cloud('smart_rice_warehouse_cloud_cache.db');

  const WarehouseDataMode(this.databaseName);
  final String databaseName;

  static WarehouseDataMode resolve({
    required bool demoMode,
    required bool useFirebaseBackend,
    required bool firebaseReady,
  }) {
    if (demoMode) return demo;
    if (!firebaseReady) {
      throw StateError(
          'Firebase chưa sẵn sàng. Không chuyển sang dữ liệu local; vui lòng thử lại.');
    }
    return useFirebaseBackend ? cloud : local;
  }
}
