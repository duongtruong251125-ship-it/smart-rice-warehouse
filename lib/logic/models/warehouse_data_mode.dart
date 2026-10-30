/// Explicit data ownership. Background refresh never selects a backend.
enum WarehouseDataMode {
  demo('smart_rice_warehouse_demo.db'),
  local('smart_rice_warehouse.db'),
  cloud('smart_rice_warehouse_cloud_cache.db');

  const WarehouseDataMode(this.databaseName);
  final String databaseName;

  static WarehouseDataMode resolve({
    required bool demoMode,
    required bool supabaseReady,
  }) {
    if (demoMode) return demo;
    if (!supabaseReady) {
      throw StateError(
        'Supabase chưa sẵn sàng. Kiểm tra SUPABASE_URL và SUPABASE_PUBLISHABLE_KEY.',
      );
    }
    return cloud;
  }
}
