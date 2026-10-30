import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/app.dart';
import 'package:smart_rice_warehouse/data/local/app_database.dart';
import 'package:smart_rice_warehouse/data/local/image_storage_service.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/data/sync/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_auth_service.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_backend.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_domain_repositories.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_inventory_transactions.dart';
import 'package:smart_rice_warehouse/data/repositories/supabase/supabase_user_profile_repository.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/contracts/authentication_service.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_data_mode.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/services/cloud_refresh_service.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';

const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
const bool useSupabaseBackend =
    bool.fromEnvironment('USE_SUPABASE', defaultValue: true);
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tzvftlwcdupzrtzbugxt.supabase.co',
);
const String supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const bool releaseBuild = bool.fromEnvironment('dart.vm.product');

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
    if (!demoMode && !useSupabaseBackend) {
      throw StateError('Ứng dụng chỉ hỗ trợ Supabase ngoài chế độ demo.');
    }
    if (releaseBuild && !demoMode && !useSupabaseBackend) {
      throw StateError('Bản phát hành phải chọn Supabase.');
    }

    final settings = SettingsService();
    await settings.init();
    final supabaseClient = demoMode
        ? null
        : await SupabaseBackend.initialize(
            url: supabaseUrl,
            publishableKey: supabasePublishableKey,
          );
    final mode = WarehouseDataMode.resolve(
      demoMode: demoMode,
      supabaseReady: supabaseClient != null,
    );
    final database = await AppDatabase.open(mode: mode);
    await database.seedLocalDataIfNeeded(demoMode: demoMode);
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
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );

    final AuthenticationService? authenticationService = supabaseClient == null
        ? null
        : SupabaseAuthService(client: supabaseClient);
    final authUid = authenticationService?.currentUser?.uid;
    final snapshot = await database.loadSnapshot(authUid: authUid);
    final UserProfileRepository? userProfiles = supabaseClient == null
        ? null
        : SupabaseUserProfileRepository(client: supabaseClient);
    final authChanges = authenticationService?.authStateChanges;

    final riceProducts = supabaseClient == null
        ? null
        : supabaseRiceProducts(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final riceCharacteristics = supabaseClient == null
        ? null
        : supabaseRiceCharacteristics(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final suppliers = supabaseClient == null
        ? null
        : supabaseSuppliers(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final customers = supabaseClient == null
        ? null
        : supabaseCustomers(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final warehouseLocations = supabaseClient == null
        ? null
        : supabaseWarehouseLocations(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final batches = supabaseClient == null
        ? null
        : SupabaseBatchRepository(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final importReceipts = supabaseClient == null
        ? null
        : supabaseImportReceipts(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final exportReceipts = supabaseClient == null
        ? null
        : supabaseExportReceipts(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final damageReports = supabaseClient == null
        ? null
        : supabaseDamageReports(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final inventoryChecks = supabaseClient == null
        ? null
        : supabaseInventoryChecks(
            client: supabaseClient,
            syncPolicy: _syncPolicy,
            authChanges: authChanges,
          );
    final transactionRepository = supabaseClient == null
        ? null
        : SupabaseInventoryTransactions(client: supabaseClient);

    DefaultDataRegistry.provider =
        demoMode ? const MockInitialDataProvider() : null;
    MediaService.initialize(const LocalMediaStorage());

    return (
      mode: mode,
      database: database,
      snapshot: snapshot,
      settings: settings,
      authenticationService:
          authenticationService ?? _NoOpAuthenticationService(),
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
      },
    ).refresh();
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

class _NoOpAuthenticationService implements AuthenticationService {
  @override
  bool get isInitialized => false;

  @override
  AuthenticatedUser? get currentUser => null;

  @override
  Stream<AuthenticatedUser?> get authStateChanges =>
      const Stream<AuthenticatedUser?>.empty();

  @override
  Future<AuthResult> signIn(
          {required String email, required String password}) async =>
      AuthResult.failure('Xác thực Supabase không khả dụng trong demo.');

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      AuthResult.failure('Xác thực Supabase không khả dụng trong demo.');

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async =>
      AuthResult.failure('Xác thực Supabase không khả dụng trong demo.');

  @override
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      AuthResult.failure('Xác thực Supabase không khả dụng trong demo.');

  @override
  Future<AuthResult> updateDisplayName(String displayName) async =>
      AuthResult.failure('Xác thực Supabase không khả dụng trong demo.');

  @override
  Future<void> signOut() async {}
}
