import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
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
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_snapshot_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/providers/theme_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/repositories/contracts/crud_repository.dart';
import 'package:smart_rice_warehouse/repositories/contracts/user_profile_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_transaction_repository.dart';
import 'package:toastification/toastification.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';

class SmartRiceWarehouseApp extends StatelessWidget {
  const SmartRiceWarehouseApp({
    super.key,
    this.database,
    this.snapshot = const AppSnapshot(),
    this.userProfiles,
    this.riceProducts,
    this.riceCharacteristics,
    this.suppliers,
    this.customers,
    this.batches,
    this.warehouseLocations,
    this.importReceipts,
    this.exportReceipts,
    this.damageReports,
    this.inventoryChecks,
    this.transactionRepository,
    required this.settings,
  });

  final AppDatabase? database;
  final AppSnapshot snapshot;
  final SettingsService settings;
  final UserProfileRepository? userProfiles;
  final CrudRepository<RiceModel>? riceProducts;
  final CrudRepository<RiceCharacteristicModel>? riceCharacteristics;
  final CrudRepository<SupplierModel>? suppliers;
  final CrudRepository<CustomerModel>? customers;
  final CrudRepository<BatchModel>? batches;
  final CrudRepository<WarehouseLocationModel>? warehouseLocations;
  final CrudRepository<ImportReceiptModel>? importReceipts;
  final CrudRepository<ExportReceiptModel>? exportReceipts;
  final CrudRepository<DamageReportModel>? damageReports;
  final CrudRepository<InventoryCheckSession>? inventoryChecks;
  final InventoryTransactionRepository? transactionRepository;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      config: const ToastificationConfig(
        maxToastLimit: 1,
      ),
      child: MultiProvider(
        providers: [
          Provider<AppSnapshot>.value(value: snapshot),
          Provider<SettingsService>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              email: snapshot.authEmail,
              passwordHash: snapshot.passwordHash,
              userName: snapshot.userName,
              userRole: snapshot.userRole,
              avatarPath: snapshot.avatarPath,
              rememberedSession: snapshot.rememberedSession,
              userProfileRepository: userProfiles,
              loadAvatarPath: database?.loadAvatarPath,
              onAvatarPersist: database?.saveAvatarPath,
              onPersist: (email, hash, remembered) => database?.saveAuth(
                email: email,
                passwordHash: hash,
                rememberedSession: remembered,
              ),
              onProfilePersist: (name, role, avatarPath) =>
                  database?.saveUserProfile(
                name: name,
                role: role,
                avatarPath: avatarPath,
              ),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => RiceProvider(
              initial: snapshot.rices,
              onPersist: database?.saveRices,
              repository: riceProducts,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => RiceCharacteristicProvider(
              initial: snapshot.characteristics,
              onPersist: database?.saveCharacteristics,
              repository: riceCharacteristics,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => SupplierProvider(
              initial: snapshot.suppliers,
              onPersist: database?.saveSuppliers,
              repository: suppliers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => CustomerProvider(
              initial: snapshot.customers,
              onPersist: database?.saveCustomers,
              repository: customers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BatchProvider(
              initial: snapshot.batches,
              onPersist: database?.saveBatches,
              repository: batches,
            ),
          ),
          ProxyProvider2<RiceProvider, BatchProvider, InventorySnapshotStore>(
            create: (_) => InventorySnapshotStore(
              initial: snapshot.snapshots,
              onPersist: database?.saveInventorySnapshots,
            ),
            update: (_, rices, batches, store) {
              final snapshotStore = store ??
                  InventorySnapshotStore(
                    initial: snapshot.snapshots,
                    onPersist: database?.saveInventorySnapshots,
                  );
              snapshotStore.synchronize(
                batches: batches.batches,
                rices: rices.rices,
              );
              return snapshotStore;
            },
          ),
          ChangeNotifierProvider(
            create: (context) => ImportProvider(
              context.read<BatchProvider>(),
              initial: snapshot.importReceipts,
              onPersist: database?.saveImportReceipts,
              repository: importReceipts,
              transactionRepository: transactionRepository,
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => ExportProvider(
              context.read<BatchProvider>(),
              initial: snapshot.exportReceipts,
              onPersist: database?.saveExportReceipts,
              repository: exportReceipts,
              transactionRepository: transactionRepository,
            ),
          ),
          ChangeNotifierProxyProvider2<RiceProvider, BatchProvider,
              AlertProvider>(
            create: (_) => AlertProvider(),
            update: (_, rices, batches, alerts) {
              final provider = alerts ?? AlertProvider();
              provider.scanAlerts(rices: rices.rices, batches: batches.batches);
              return provider;
            },
          ),
          ChangeNotifierProxyProvider3<RiceProvider, ExportProvider,
              BatchProvider, ForecastProvider>(
            create: (_) => ForecastProvider(),
            update: (_, rices, exports, batches, forecasts) {
              final provider = forecasts ?? ForecastProvider();
              provider.refreshForecasts(
                rices: rices.rices,
                exportReceipts: exports.receipts,
                batchProvider: batches,
              );
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) => WarehouseProvider(
              initial: snapshot.locations,
              onPersist: database?.saveLocations,
              repository: warehouseLocations,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => InventoryCheckProvider(
              initial: snapshot.inventoryChecks,
              onPersist: database?.saveInventoryChecks,
              repository: inventoryChecks,
              transactionRepository: transactionRepository,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(
              initialDarkMode: settings.isDarkMode,
              onChanged: settings.setDarkMode,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => DamageProvider(
              initial: snapshot.damageReports,
              onPersist: database?.saveDamageReports,
              repository: damageReports,
              transactionRepository: transactionRepository,
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            final themeProvider = context.watch<ThemeProvider>();
            return MaterialApp(
              navigatorKey: AppRoutes.navigatorKey,
              title: 'Smart Rice Warehouse',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode,
              initialRoute: AppRoutes.splash,
              routes: AppRoutes.routes,
              onGenerateRoute: AppRoutes.onGenerateRoute,
            );
          },
        ),
      ),
    );
  }
}
