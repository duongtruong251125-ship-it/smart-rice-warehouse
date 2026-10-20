import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
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
import 'package:smart_rice_warehouse/logic/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_snapshot_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/presentation/theme/theme_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:toastification/toastification.dart';
import 'package:smart_rice_warehouse/logic/contracts/app_settings.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/presentation/widgets/auth_route_guard.dart';

class SmartRiceWarehouseApp extends StatelessWidget {
  const SmartRiceWarehouseApp({
    super.key,
    this.database,
    this.demoMode = false,
    this.snapshot = const AppSnapshot(),
    this.userProfiles,
    this.authenticationService,
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
    this.onForceCloudSync,
    this.onLegacyMigration,
    required this.settings,
  });

  final AppDatabase? database;
  final bool demoMode;
  final AppSnapshot snapshot;
  final AppSettings settings;
  final UserProfileRepository? userProfiles;
  final AuthenticationService? authenticationService;
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
  final InventoryTransactions? transactionRepository;
  final Future<({bool success, String? message})> Function()? onForceCloudSync;
  final Future<({bool success, String? message})> Function()? onLegacyMigration;

  List<T>? _initial<T>(List<T>? values) => values ?? (demoMode ? null : <T>[]);

  @override
  Widget build(BuildContext context) {
    Provider.debugCheckInvalidValueType = null;
    return ToastificationWrapper(
      config: const ToastificationConfig(
        maxToastLimit: 1,
      ),
      child: MultiProvider(
        providers: [
          Provider<AppSnapshot>.value(value: snapshot),
          Provider<AppSettings>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              demoMode: demoMode,
              email: snapshot.authEmail,
              passwordHash: snapshot.passwordHash,
              userName: snapshot.userName,
              userRole: snapshot.userRole,
              avatarPath: snapshot.avatarPath,
              rememberedSession: snapshot.rememberedSession,
              authenticationService: authenticationService,
              userProfileRepository: userProfiles,
              loadAvatarPath: database?.loadAvatarPath,
              onAvatarPersist: database?.saveAvatarPath,
              onForceCloudSync: onForceCloudSync,
              onLegacyMigration: onLegacyMigration,
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
              initial: _initial(snapshot.rices),
              onPersist: database?.saveRices,
              repository: riceProducts,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => RiceCharacteristicProvider(
              initial: _initial(snapshot.characteristics),
              onPersist: database?.saveCharacteristics,
              repository: riceCharacteristics,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => SupplierProvider(
              initial: _initial(snapshot.suppliers),
              onPersist: database?.saveSuppliers,
              repository: suppliers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => CustomerProvider(
              initial: _initial(snapshot.customers),
              onPersist: database?.saveCustomers,
              repository: customers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BatchProvider(
              initial: _initial(snapshot.batches),
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
              initial: _initial(snapshot.importReceipts),
              onPersist: database?.saveImportReceipts,
              repository: importReceipts,
              transactionRepository: transactionRepository,
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => ExportProvider(
              context.read<BatchProvider>(),
              initial: _initial(snapshot.exportReceipts),
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
              initial: _initial(snapshot.locations),
              onPersist: database?.saveLocations,
              repository: warehouseLocations,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => InventoryCheckProvider(
              initial: _initial(snapshot.inventoryChecks),
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
              initial: _initial(snapshot.damageReports),
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
              builder: (_, child) => AuthSessionGuard(child: child!),
              routes: AppRoutes.routes.map((name, builder) => MapEntry(
                  name,
                  name == AppRoutes.splash || name == AppRoutes.login
                      ? builder
                      : (context) => AuthRouteGuard(builder: builder))),
              onGenerateRoute: (settings) {
                final route = AppRoutes.onGenerateRoute(settings);
                if (route is MaterialPageRoute) {
                  return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => AuthRouteGuard(builder: route.builder));
                }
                return route;
              },
            );
          },
        ),
      ),
    );
  }
}
