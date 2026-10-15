import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
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
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/providers/theme_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';

class SmartRiceWarehouseApp extends StatelessWidget {
  const SmartRiceWarehouseApp({
    super.key,
    this.database,
    this.snapshot = const AppSnapshot(),
    required this.settings,
  });

  final AppDatabase? database;
  final AppSnapshot snapshot;
  final SettingsService settings;

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
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => RiceCharacteristicProvider(
              initial: snapshot.characteristics,
              onPersist: database?.saveCharacteristics,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => SupplierProvider(
              initial: snapshot.suppliers,
              onPersist: database?.saveSuppliers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => CustomerProvider(
              initial: snapshot.customers,
              onPersist: database?.saveCustomers,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BatchProvider(
              initial: snapshot.batches,
              onPersist: database?.saveBatches,
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
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => ExportProvider(
              context.read<BatchProvider>(),
              initial: snapshot.exportReceipts,
              onPersist: database?.saveExportReceipts,
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
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => InventoryCheckProvider(
              initial: snapshot.inventoryChecks,
              onPersist: database?.saveInventoryChecks,
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
