/// Centralized Cloud Firestore collection and document paths.
///
/// Keeping paths here prevents UI and Provider code from scattering collection
/// names throughout the application.
abstract final class FirestorePaths {
  static const users = 'users';
  static const riceProducts = 'rice_products';
  static const riceCharacteristics = 'rice_characteristics';
  static const suppliers = 'suppliers';
  static const customers = 'customers';
  static const batches = 'batches';
  static const importReceipts = 'import_receipts';
  static const exportReceipts = 'export_receipts';
  static const damageReports = 'damage_reports';
  static const inventoryChecks = 'inventory_checks';
  static const inventorySnapshots = 'inventory_snapshots';
  static const stockMovements = 'stock_movements';
  static const warehouseLocations = 'warehouse_locations';
  static const migrationRuns = 'migration_runs';

  static String user(String uid) => document(users, uid);
  static String riceProduct(String id) => document(riceProducts, id);
  static String riceCharacteristic(String id) =>
      document(riceCharacteristics, id);
  static String supplier(String id) => document(suppliers, id);
  static String customer(String id) => document(customers, id);
  static String batch(String id) => document(batches, id);
  static String importReceipt(String id) => document(importReceipts, id);
  static String exportReceipt(String id) => document(exportReceipts, id);
  static String damageReport(String id) => document(damageReports, id);
  static String inventoryCheck(String id) => document(inventoryChecks, id);
  static String stockMovement(String id) => document(stockMovements, id);
  static String warehouseLocation(String id) =>
      document(warehouseLocations, id);
  static String migrationRun(String id) => document(migrationRuns, id);

  static String document(String collection, String id) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || normalizedId.contains('/')) {
      throw ArgumentError.value(
        id,
        'id',
        'Firestore document ID must be non-empty and must not contain a slash.',
      );
    }
    return '$collection/$normalizedId';
  }
}
