import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_paths.dart';
import 'package:smart_rice_warehouse/core/services/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/repositories/contracts/crud_repository.dart';
import 'package:smart_rice_warehouse/repositories/contracts/user_profile_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/customer_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/firestore_collection_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/firestore_user_profile_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_transaction_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/rice_characteristic_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/rice_product_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/supplier_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/warehouse_location_mapper.dart';

typedef BootstrapData = ({
  AppDatabase database,
  AppSnapshot snapshot,
  SettingsService settings,
  UserProfileRepository? userProfiles,
  CrudRepository<RiceModel>? riceProducts,
  CrudRepository<RiceCharacteristicModel>? riceCharacteristics,
  CrudRepository<SupplierModel>? suppliers,
  CrudRepository<CustomerModel>? customers,
  CrudRepository<WarehouseLocationModel>? warehouseLocations,
  CrudRepository<BatchModel>? batches,
  CrudRepository<ImportReceiptModel>? importReceipts,
  CrudRepository<ExportReceiptModel>? exportReceipts,
  CrudRepository<DamageReportModel>? damageReports,
  CrudRepository<InventoryCheckSession>? inventoryChecks,
  InventoryTransactionRepository? transactionRepository,
});

class WarehouseBootstrapApp extends StatefulWidget {
  const WarehouseBootstrapApp({super.key});

  @override
  State<WarehouseBootstrapApp> createState() => _WarehouseBootstrapAppState();
}

class _WarehouseBootstrapAppState extends State<WarehouseBootstrapApp> {
  late Future<BootstrapData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<BootstrapData> _load() async {
    final settings = SettingsService();
    await settings.init();
    // Khởi tạo an toàn Firebase (nếu có cấu hình, nếu không sẽ tự động chạy Local)
    final firebaseReady = await FirebaseAuthService.instance.initialize();
    final database = await AppDatabase.open();
    final snapshot = await database.loadSnapshot(
      authUid: FirebaseAuthService.instance.currentUser?.uid,
    );
    final userProfiles = firebaseReady
        ? FirestoreUserProfileRepository(
            firestore: FirebaseFirestore.instance,
          )
        : null;
    final firestore = firebaseReady ? FirebaseFirestore.instance : null;

    final riceProducts = firestore == null
        ? null
        : FirestoreCollectionRepository<RiceModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.riceProducts,
            mapper: const RiceProductMapper(),
            orderByField: 'code',
            manageTimestamps: true,
          );

    final riceCharacteristics = firestore == null
        ? null
        : FirestoreCollectionRepository<RiceCharacteristicModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.riceCharacteristics,
            mapper: const RiceCharacteristicMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final suppliers = firestore == null
        ? null
        : FirestoreCollectionRepository<SupplierModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.suppliers,
            mapper: const SupplierMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final customers = firestore == null
        ? null
        : FirestoreCollectionRepository<CustomerModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.customers,
            mapper: const CustomerMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final warehouseLocations = firestore == null
        ? null
        : FirestoreCollectionRepository<WarehouseLocationModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.warehouseLocations,
            mapper: const WarehouseLocationMapper(),
            orderByField: 'code',
            manageTimestamps: true,
          );

    final batches = firestore == null
        ? null
        : FirestoreCollectionRepository<BatchModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.batches,
            mapper: const BatchMapper(),
            orderByField: 'code',
            manageTimestamps: true,
          );

    final importReceipts = firestore == null
        ? null
        : FirestoreCollectionRepository<ImportReceiptModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.importReceipts,
            mapper: const ImportReceiptMapper(),
            orderByField: 'date',
            manageTimestamps: true,
          );

    final exportReceipts = firestore == null
        ? null
        : FirestoreCollectionRepository<ExportReceiptModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.exportReceipts,
            mapper: const ExportReceiptMapper(),
            orderByField: 'date',
            manageTimestamps: true,
          );

    final damageReports = firestore == null
        ? null
        : FirestoreCollectionRepository<DamageReportModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.damageReports,
            mapper: const DamageReportMapper(),
            orderByField: 'reportedAt',
            manageTimestamps: true,
          );

    final inventoryChecks = firestore == null
        ? null
        : FirestoreCollectionRepository<InventoryCheckSession>(
            firestore: firestore,
            collectionPath: FirestorePaths.inventoryChecks,
            mapper: const InventoryCheckMapper(),
            orderByField: 'createdAt',
            manageTimestamps: true,
          );

    final transactionRepository = firestore == null
        ? null
        : InventoryTransactionRepository(firestore: firestore);

    return (
      database: database,
      snapshot: snapshot,
      settings: settings,
      userProfiles: userProfiles,
      riceProducts: riceProducts,
      riceCharacteristics: riceCharacteristics,
      suppliers: suppliers,
      customers: customers,
      warehouseLocations: warehouseLocations,
      batches: batches,
      importReceipts: importReceipts,
      exportReceipts: exportReceipts,
      damageReports: damageReports,
      inventoryChecks: inventoryChecks,
      transactionRepository: transactionRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapData>(
      future: _future,
      builder: (context, state) {
        if (state.hasData) {
          final data = state.data!;
          return SmartRiceWarehouseApp(
            database: data.database,
            settings: data.settings,
            snapshot: data.snapshot,
            userProfiles: data.userProfiles,
            riceProducts: data.riceProducts,
            riceCharacteristics: data.riceCharacteristics,
            suppliers: data.suppliers,
            customers: data.customers,
            warehouseLocations: data.warehouseLocations,
            batches: data.batches,
            importReceipts: data.importReceipts,
            exportReceipts: data.exportReceipts,
            damageReports: data.damageReports,
            inventoryChecks: data.inventoryChecks,
            transactionRepository: data.transactionRepository,
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: _BootstrapScreen(
            error: state.error,
            onRetry: () => setState(() => _future = _load()),
          ),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Đang khởi động Smart Rice Warehouse...',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.dangerColor,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể khởi động ứng dụng: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
