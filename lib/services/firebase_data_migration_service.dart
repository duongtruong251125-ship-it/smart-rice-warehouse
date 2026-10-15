import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_paths.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
import 'package:smart_rice_warehouse/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/customer_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/rice_characteristic_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/rice_product_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/supplier_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/warehouse_location_mapper.dart';

class MigrationResult {
  const MigrationResult({
    required this.isSuccess,
    required this.message,
    this.migratedCounts = const {},
  });

  final bool isSuccess;
  final String message;
  final Map<String, int> migratedCounts;
}

class FirebaseDataMigrationService {
  FirebaseDataMigrationService({
    required FirebaseFirestore firestore,
    required AppDatabase database,
  })  : _firestore = firestore,
        _database = database;

  final FirebaseFirestore _firestore;
  final AppDatabase _database;

  static const _riceMapper = RiceProductMapper();
  static const _charMapper = RiceCharacteristicMapper();
  static const _supplierMapper = SupplierMapper();
  static const _customerMapper = CustomerMapper();
  static const _locationMapper = WarehouseLocationMapper();
  static const _batchMapper = BatchMapper();
  static const _importMapper = ImportReceiptMapper();
  static const _exportMapper = ExportReceiptMapper();
  static const _damageMapper = DamageReportMapper();
  static const _checkMapper = InventoryCheckMapper();

  /// Kiểm tra xem đã từng migration thành công chưa
  Future<bool> isMigrationCompleted({String runId = 'default_run'}) async {
    try {
      final doc = await _firestore
          .collection(FirestorePaths.migrationRuns)
          .doc(runId)
          .get();
      return doc.exists && doc.data()?['status'] == 'completed';
    } catch (_) {
      return false;
    }
  }

  /// Thực thi migration từ SQLite sang Cloud Firestore
  Future<MigrationResult> runMigration({
    String runId = 'default_run',
    bool force = false,
  }) async {
    try {
      if (!force && await isMigrationCompleted(runId: runId)) {
        return const MigrationResult(
          isSuccess: true,
          message: 'Dữ liệu đã được chuyển đổi trước đó.',
        );
      }

      // 1. Nạp snapshot từ SQLite
      final snapshot = await _database.loadSnapshot();
      final counts = <String, int>{};

      // 2. Ghi nhận bắt đầu migration run
      await _firestore.collection(FirestorePaths.migrationRuns).doc(runId).set({
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
        'schemaVersion': 1,
      });

      // 3. Batch write cho Rice Characteristics
      final characteristics = snapshot.characteristics ?? const [];
      if (characteristics.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in characteristics) {
          final ref = _firestore.collection(FirestorePaths.riceCharacteristics).doc(item.id);
          batch.set(ref, _charMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['characteristics'] = characteristics.length;
      }

      // 4. Batch write cho Rice Products (loại bỏ imagePath cục bộ)
      final rices = snapshot.rices ?? const [];
      if (rices.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in rices) {
          final ref = _firestore.collection(FirestorePaths.riceProducts).doc(item.id);
          // Không đẩy imagePath lên Firestore
          batch.set(ref, _riceMapper.toFirestore(item.copyWith(imagePath: null), null));
        }
        await batch.commit();
        counts['rices'] = rices.length;
      }

      // 5. Batch write cho Suppliers
      final suppliers = snapshot.suppliers ?? const [];
      if (suppliers.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in suppliers) {
          final ref = _firestore.collection(FirestorePaths.suppliers).doc(item.id);
          batch.set(ref, _supplierMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['suppliers'] = suppliers.length;
      }

      // 6. Batch write cho Customers
      final customers = snapshot.customers ?? const [];
      if (customers.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in customers) {
          final ref = _firestore.collection(FirestorePaths.customers).doc(item.id);
          batch.set(ref, _customerMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['customers'] = customers.length;
      }

      // 7. Batch write cho Warehouse Locations
      final locations = snapshot.locations ?? const [];
      if (locations.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in locations) {
          final ref = _firestore.collection(FirestorePaths.warehouseLocations).doc(item.id);
          batch.set(ref, _locationMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['locations'] = locations.length;
      }

      // 8. Batch write cho Batches
      final batches = snapshot.batches ?? const [];
      if (batches.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in batches) {
          final ref = _firestore.collection(FirestorePaths.batches).doc(item.id);
          batch.set(ref, _batchMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['batches'] = batches.length;
      }

      // 9. Batch write cho Import Receipts
      final importReceipts = snapshot.importReceipts ?? const [];
      if (importReceipts.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in importReceipts) {
          final ref = _firestore.collection(FirestorePaths.importReceipts).doc(item.id);
          batch.set(ref, _importMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['importReceipts'] = importReceipts.length;
      }

      // 10. Batch write cho Export Receipts
      final exportReceipts = snapshot.exportReceipts ?? const [];
      if (exportReceipts.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in exportReceipts) {
          final ref = _firestore.collection(FirestorePaths.exportReceipts).doc(item.id);
          batch.set(ref, _exportMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['exportReceipts'] = exportReceipts.length;
      }

      // 11. Batch write cho Damage Reports (loại bỏ imagePath)
      final damageReports = snapshot.damageReports ?? const [];
      if (damageReports.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in damageReports) {
          final ref = _firestore.collection(FirestorePaths.damageReports).doc(item.id);
          batch.set(ref, _damageMapper.toFirestore(item.copyWith(imagePath: null), null));
        }
        await batch.commit();
        counts['damageReports'] = damageReports.length;
      }

      // 12. Batch write cho Inventory Checks
      final inventoryChecks = snapshot.inventoryChecks ?? const [];
      if (inventoryChecks.isNotEmpty) {
        final batch = _firestore.batch();
        for (final item in inventoryChecks) {
          final ref = _firestore.collection(FirestorePaths.inventoryChecks).doc(item.id);
          batch.set(ref, _checkMapper.toFirestore(item, null));
        }
        await batch.commit();
        counts['inventoryChecks'] = inventoryChecks.length;
      }

      // 13. Ghi nhận hoàn tất vào migration_runs
      await _firestore.collection(FirestorePaths.migrationRuns).doc(runId).set({
        'completedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'counts': counts,
      }, SetOptions(merge: true));

      return MigrationResult(
        isSuccess: true,
        message: 'Chuyển đổi dữ liệu sang Firestore thành công.',
        migratedCounts: counts,
      );
    } catch (e) {
      return MigrationResult(
        isSuccess: false,
        message: 'Lỗi trong quá trình chuyển đổi: $e',
      );
    }
  }
}
