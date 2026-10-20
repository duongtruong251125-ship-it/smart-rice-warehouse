import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_paths.dart';
import 'package:smart_rice_warehouse/data/firebase/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/data/local/app_database.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_batch_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/customer_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_collection_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_user_profile_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/callable_inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/rice_characteristic_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/rice_product_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/supplier_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/warehouse_location_mapper.dart';

import 'package:smart_rice_warehouse/data/firebase/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/firebase/firebase_data_migration_service.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_data_mode.dart';
import 'package:smart_rice_warehouse/logic/services/cloud_refresh_service.dart';
import 'package:smart_rice_warehouse/data/local/image_storage_service.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

/// Controls only the warehouse/business collections. Firebase Authentication
/// and its user-profile collection are initialized independently below so an
/// app can use real accounts without unexpectedly replacing local warehouse
/// data with an empty Firestore project.
const bool useFirebaseBackend = bool.fromEnvironment(
  'USE_FIREBASE',
  defaultValue: true,
);
const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

typedef BootstrapData = ({
  WarehouseDataMode mode,
  AppDatabase database,
  AppSnapshot snapshot,
  SettingsService settings,
  AuthenticationService authenticationService,
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
  InventoryTransactions? transactionRepository,
});

class WarehouseBootstrapApp extends StatefulWidget {
  const WarehouseBootstrapApp({super.key});

  @override
  State<WarehouseBootstrapApp> createState() => _WarehouseBootstrapAppState();
}

class _WarehouseBootstrapAppState extends State<WarehouseBootstrapApp>
    with WidgetsBindingObserver {
  late Future<BootstrapData> _future;
  BusinessSyncPolicy? _syncPolicy;
  SettingsService? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings?.removeListener(_updateSyncSetting);
    _syncPolicy?.dispose();
    _settings?.dispose();
    super.dispose();
  }

  void _updateSyncSetting() {
    _syncPolicy?.configure(backgroundSyncEnabled: _settings?.backgroundSync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPolicy?.configure(foreground: state == AppLifecycleState.resumed);
  }

  Future<BootstrapData> _load() async {
    final settings = SettingsService();
    await settings.init();
    final firebaseReady =
        !demoMode && await FirebaseAuthService.instance.initialize();
    final mode = WarehouseDataMode.resolve(
        demoMode: demoMode,
        useFirebaseBackend: useFirebaseBackend,
        firebaseReady: firebaseReady);
    final database = await AppDatabase.open(mode: mode);
    await database.seedLocalDataIfNeeded(
        demoMode: mode == WarehouseDataMode.demo);
    if (!mounted) {
      await database.close();
      settings.dispose();
      throw StateError('Khởi tạo đã bị hủy.');
    }
    _settings?.removeListener(_updateSyncSetting);
    _settings = settings;
    _syncPolicy =
        BusinessSyncPolicy(backgroundSyncEnabled: settings.backgroundSync);
    settings.addListener(_updateSyncSetting);
    _syncPolicy!.configure(
        foreground: WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed);

    final authUid =
        firebaseReady ? FirebaseAuthService.instance.currentUser?.uid : null;
    final snapshot = await database.loadSnapshot(authUid: authUid);
    final userProfiles = firebaseReady
        ? FirestoreUserProfileRepository(firestore: FirebaseFirestore.instance)
        : null;
    final firestore =
        mode == WarehouseDataMode.cloud ? FirebaseFirestore.instance : null;

    final riceProducts = firestore == null
        ? null
        : FirestoreCollectionRepository<RiceModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.riceProducts,
            syncPolicy: _syncPolicy,
            mapper: const RiceProductMapper(),
            orderByField: 'code',
            manageTimestamps: true,
          );

    final riceCharacteristics = firestore == null
        ? null
        : FirestoreCollectionRepository<RiceCharacteristicModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.riceCharacteristics,
            syncPolicy: _syncPolicy,
            mapper: const RiceCharacteristicMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final suppliers = firestore == null
        ? null
        : FirestoreCollectionRepository<SupplierModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.suppliers,
            syncPolicy: _syncPolicy,
            mapper: const SupplierMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final customers = firestore == null
        ? null
        : FirestoreCollectionRepository<CustomerModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.customers,
            syncPolicy: _syncPolicy,
            mapper: const CustomerMapper(),
            orderByField: 'name',
            manageTimestamps: true,
          );

    final warehouseLocations = firestore == null
        ? null
        : FirestoreCollectionRepository<WarehouseLocationModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.warehouseLocations,
            syncPolicy: _syncPolicy,
            mapper: const WarehouseLocationMapper(),
            orderByField: 'code',
            manageTimestamps: true,
          );

    final batches = firestore == null
        ? null
        : FirestoreBatchRepository(
            firestore: firestore, syncPolicy: _syncPolicy);

    final importReceipts = firestore == null
        ? null
        : FirestoreCollectionRepository<ImportReceiptModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.importReceipts,
            syncPolicy: _syncPolicy,
            mapper: const ImportReceiptMapper(),
            orderByField: 'date',
            manageTimestamps: true,
          );

    final exportReceipts = firestore == null
        ? null
        : FirestoreCollectionRepository<ExportReceiptModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.exportReceipts,
            syncPolicy: _syncPolicy,
            mapper: const ExportReceiptMapper(),
            orderByField: 'date',
            manageTimestamps: true,
          );

    final damageReports = firestore == null
        ? null
        : FirestoreCollectionRepository<DamageReportModel>(
            firestore: firestore,
            collectionPath: FirestorePaths.damageReports,
            syncPolicy: _syncPolicy,
            mapper: const DamageReportMapper(),
            orderByField: 'reportedAt',
            manageTimestamps: true,
          );

    final inventoryChecks = firestore == null
        ? null
        : FirestoreCollectionRepository<InventoryCheckSession>(
            firestore: firestore,
            collectionPath: FirestorePaths.inventoryChecks,
            syncPolicy: _syncPolicy,
            mapper: const InventoryCheckMapper(),
            orderByField: 'createdAt',
            manageTimestamps: true,
          );

    final transactionRepository =
        firestore == null ? null : CallableInventoryTransactions();

    DefaultDataRegistry.provider =
        mode == WarehouseDataMode.demo ? const MockInitialDataProvider() : null;
    MediaService.initialize(const LocalMediaStorage());

    return (
      mode: mode,
      database: database,
      snapshot: snapshot,
      settings: settings,
      authenticationService: FirebaseAuthService.instance,
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

  Future<({bool success, String? message})> _refresh(BootstrapData data) async {
    if (data.mode != WarehouseDataMode.cloud) {
      try {
        await data.database.flush();
        return (
          success: true,
          message: 'Đã lưu dữ liệu trên thiết bị; không upload cloud.'
        );
      } catch (error) {
        return (
          success: false,
          message: 'Không thể lưu dữ liệu thiết bị: $error'
        );
      }
    }
    return CloudRefreshService(
        authentication: data.authenticationService,
        profiles: data.userProfiles!,
        refreshData: () async {
          await Future.wait([
            data.riceProducts!.getAll(),
            data.riceCharacteristics!.getAll(),
            data.suppliers!.getAll(),
            data.customers!.getAll(),
            data.warehouseLocations!.getAll(),
            data.batches!.getAll(),
            data.importReceipts!.getAll(),
            data.exportReceipts!.getAll(),
            data.damageReports!.getAll(),
            data.inventoryChecks!.getAll(),
          ]);
        }).refresh();
  }

  Future<({bool success, String? message})> _migrateLegacy(
      BootstrapData data) async {
    final result = await FirebaseDataMigrationService(
        authentication: data.authenticationService,
        profiles: data.userProfiles!,
        loadLegacySnapshot: () async {
          final legacy = await AppDatabase.open(mode: WarehouseDataMode.local);
          try {
            return await legacy.loadSnapshot();
          } finally {
            await legacy.close();
          }
        }).runMigration();
    return (success: result.isSuccess, message: result.message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapData>(
      future: _future,
      builder: (context, state) {
        if (state.hasData) {
          final data = state.data!;
          return SmartRiceWarehouseApp(
            demoMode: demoMode,
            database: data.database,
            settings: data.settings,
            snapshot: data.snapshot,
            authenticationService: data.authenticationService,
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
            onForceCloudSync: () => _refresh(data),
            onLegacyMigration: data.mode == WarehouseDataMode.cloud
                ? () => _migrateLegacy(data)
                : null,
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
