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
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
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
      child: MultiProvider(
        providers: [
          Provider<AppSnapshot>.value(value: snapshot),
          Provider<SettingsService>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              email: snapshot.authEmail,
              passwordHash: snapshot.passwordHash,
              rememberedSession: snapshot.rememberedSession,
              onPersist: (email, hash, remembered) => database?.saveAuth(
                email: email,
                passwordHash: hash,
                rememberedSession: remembered,
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
          ChangeNotifierProvider(
            create: (context) => ImportProvider(context.read<BatchProvider>(), database: database,
              initial: snapshot.importReceipts,
              onPersist: database?.saveImportReceipts,
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => ExportProvider(context.read<BatchProvider>(), database: database,
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
            create: (_) => DamageProvider(
              initial: snapshot.damageReports,
              onPersist: database?.saveDamageReports,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Smart Rice Warehouse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
