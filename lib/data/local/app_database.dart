import 'dart:async';
import 'dart:convert';

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
import 'package:smart_rice_warehouse/logic/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/data/local/seed_migration_policy.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_data_mode.dart';
import 'package:sqflite/sqflite.dart';

class AppSnapshot {
  final List<InventorySnapshotModel> snapshots;
  const AppSnapshot({
    this.snapshots = const [],
    this.rices,
    this.characteristics,
    this.suppliers,
    this.customers,
    this.batches,
    this.importReceipts,
    this.exportReceipts,
    this.locations,
    this.damageReports,
    this.inventoryChecks,
    this.authEmail,
    this.passwordHash,
    this.userName,
    this.userRole,
    this.avatarPath,
    this.rememberedSession = false,
  });

  final List<RiceModel>? rices;
  final List<RiceCharacteristicModel>? characteristics;
  final List<SupplierModel>? suppliers;
  final List<CustomerModel>? customers;
  final List<BatchModel>? batches;
  final List<ImportReceiptModel>? importReceipts;
  final List<ExportReceiptModel>? exportReceipts;
  final List<WarehouseLocationModel>? locations;
  final List<DamageReportModel>? damageReports;
  final List<InventoryCheckSession>? inventoryChecks;
  final String? authEmail;
  final String? passwordHash;
  final String? userName;
  final String? userRole;
  final String? avatarPath;
  final bool rememberedSession;
}

class AppDatabase {
  AppDatabase._(this._database);

  static const int _localSeedVersion = 4;

  final Database _database;
  Future<void> _writeQueue = Future<void>.value();

  static Future<AppDatabase> open({
    WarehouseDataMode mode = WarehouseDataMode.local,
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final driver = factory ?? databaseFactory;
    final root = databasePath == null ? await driver.getDatabasesPath() : null;
    final database = await driver.openDatabase(
      databasePath ?? '$root/${mode.databaseName}',
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute(
                'CREATE TABLE app_state (state_key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
              )),
    );
    return AppDatabase._(database);
  }

  /// Installs the bundled warehouse sample data once for local/offline mode.
  ///
  /// A version marker prevents deleted records from being recreated on every
  /// launch. Increment [_localSeedVersion] only when a deliberate seed-data
  /// migration is required.
  Future<bool> seedLocalDataIfNeeded({
    bool demoMode = false,
    SeedMigrationPolicy migrationPolicy = const SeedMigrationPolicy(),
  }) async {
    // Do not even update the seed marker in real/local/cache databases.
    if (!demoMode) return false;
    final installedVersion = await _loadValue<int>('local_seed_version') ?? 0;
    if (installedVersion >= _localSeedVersion) return false;

    if (installedVersion == 0) {
      // Bảo toàn dữ liệu cũ: nếu cơ sở dữ liệu đã có dữ liệu nhưng chưa có marker version,
      // tuyệt đối không ghi đè dữ liệu mẫu MockData.
      final existingData = await _database.query(
        'app_state',
        columns: const ['state_key'],
        where: "state_key != 'local_seed_version'",
        limit: 1,
      );

      if (migrationPolicy.shouldSkipInitialSeedOverwrite(
        installedVersion: installedVersion,
        hasExistingData: existingData.isNotEmpty,
      )) {
        await _database.transaction((transaction) async {
          await _writeSeedVersion(transaction);
        });
        return true;
      }

      final collections = <String, List<Map<String, Object?>>>{
        'rices': MockData.rices.map((item) => item.toJson()).toList(),
        'characteristics': MockData.defaultCharacteristics
            .map((item) => item.toJson())
            .toList(),
        'suppliers': MockData.suppliers.map((item) => item.toJson()).toList(),
        'customers': MockData.customers.map((item) => item.toJson()).toList(),
        'batches': MockData.batches.map((item) => item.toJson()).toList(),
        'import_receipts':
            MockData.importReceipts.map((item) => item.toJson()).toList(),
        'export_receipts':
            MockData.exportReceipts.map((item) => item.toJson()).toList(),
        'locations':
            MockData.warehouseLocations.map((item) => item.toJson()).toList(),
        'damage_reports':
            MockData.initialDamageReports.map((item) => item.toJson()).toList(),
        'inventory_checks': MockData.initialInventoryChecks
            .map((item) => item.toJson())
            .toList(),
      };

      await _database.transaction((transaction) async {
        for (final entry in collections.entries) {
          await transaction.insert(
            'app_state',
            {'state_key': entry.key, 'payload': jsonEncode(entry.value)},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await _writeSeedVersion(transaction);
      });
      return true;
    }

    // Version 2 adds bundled product images. Preserve all user-created data
    // and only fill missing image paths for the original sample rice records.
    if (installedVersion < 2) {
      final existingRices =
          await _load('rices', RiceModel.fromJson) ?? const [];
      final updatedRices = migrationPolicy.migrateRicesV1ToV2(
        existingRices: existingRices,
        sampleRices: MockData.rices,
      );

      await _replaceCollection(
        'rices',
        updatedRices.map((item) => item.toJson()).toList(),
      );
    }

    // Version 3 adds photographic damage-report examples.
    // Ưu tiên bảo toàn dữ liệu cũ: chỉ bổ sung ảnh cho báo cáo mẫu cũ nếu có,
    // tuyệt đối không chèn thêm báo cáo mẫu vào lịch sử thật của người dùng.
    if (installedVersion < 3) {
      final existingReports =
          await _load('damage_reports', DamageReportModel.fromJson) ?? const [];
      if (existingReports.isNotEmpty) {
        final updatedReports = migrationPolicy.migrateDamageReportsV2ToV3(
          existingReports: existingReports,
          sampleReports: MockData.initialDamageReports,
        );

        await _replaceCollection(
          'damage_reports',
          updatedReports.map((item) => item.toJson()).toList(),
        );
      }
    }

    // Version 4: Tuyệt đối KHÔNG thêm lô hàng hoặc giao dịch mẫu vào database đang hoạt động,
    // cũng không khôi phục dữ liệu mẫu người dùng đã xóa.
    // Chỉ cập nhật bổ sung đường dẫn ảnh mẫu nếu bản ghi gạo mẫu tương ứng vẫn đang tồn tại.
    if (installedVersion < 4) {
      final existingRices =
          await _load('rices', RiceModel.fromJson) ?? const [];
      if (existingRices.isNotEmpty) {
        final migratedRices = migrationPolicy.migrateRicesV3ToV4(
          existingRices: existingRices,
          sampleRices: MockData.rices,
        );
        await _replaceCollection(
          'rices',
          migratedRices.map((item) => item.toJson()).toList(),
        );
      }
    }

    await _database.transaction((transaction) async {
      await _writeSeedVersion(transaction);
    });
    return true;
  }

  Future<void> _replaceCollection(
    String key,
    List<Map<String, Object?>> values,
  ) async {
    await _database.insert(
      'app_state',
      {'state_key': key, 'payload': jsonEncode(values)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _writeSeedVersion(Transaction transaction) async {
    await transaction.insert(
      'app_state',
      {
        'state_key': 'local_seed_version',
        'payload': jsonEncode(_localSeedVersion),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSnapshot> loadSnapshot({String? authUid}) async {
    return AppSnapshot(
      rices: await _load('rices', RiceModel.fromJson),
      characteristics:
          await _load('characteristics', RiceCharacteristicModel.fromJson),
      suppliers: await _load('suppliers', SupplierModel.fromJson),
      customers: await _load('customers', CustomerModel.fromJson),
      batches: await _load('batches', BatchModel.fromJson),
      importReceipts:
          await _load('import_receipts', ImportReceiptModel.fromJson),
      exportReceipts:
          await _load('export_receipts', ExportReceiptModel.fromJson),
      locations: await _load('locations', WarehouseLocationModel.fromJson),
      damageReports: await _load('damage_reports', DamageReportModel.fromJson),
      inventoryChecks:
          await _load('inventory_checks', InventoryCheckSession.fromJson),
      snapshots: await _load(
            'inventory_snapshots',
            InventorySnapshotModel.fromJson,
          ) ??
          const [],
      authEmail: await _loadValue<String>('auth_email'),
      passwordHash: await _loadValue<String>('password_hash'),
      userName: await _loadValue<String>('user_name'),
      userRole: await _loadValue<String>('user_role'),
      avatarPath: await _loadAvatarForSnapshot(authUid),
      rememberedSession: await _loadValue<bool>('remembered_session') ?? false,
    );
  }

  Future<T?> _loadValue<T>(String key) async {
    final rows = await _database.query(
      'app_state',
      columns: const ['payload'],
      where: 'state_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload']! as String) as T;
  }

  Future<List<T>?> _load<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final rows = await _database.query(
      'app_state',
      columns: const ['payload'],
      where: 'state_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final values =
        jsonDecode(rows.first['payload']! as String) as List<dynamic>;
    return values
        .map((item) => decode(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  void saveRices(List<RiceModel> value) =>
      _save('rices', value.map((item) => item.toJson()).toList());
  void saveCharacteristics(List<RiceCharacteristicModel> value) =>
      _save('characteristics', value.map((item) => item.toJson()).toList());
  void saveSuppliers(List<SupplierModel> value) =>
      _save('suppliers', value.map((item) => item.toJson()).toList());
  void saveCustomers(List<CustomerModel> value) =>
      _save('customers', value.map((item) => item.toJson()).toList());
  void saveBatches(List<BatchModel> value) =>
      _save('batches', value.map((item) => item.toJson()).toList());
  void saveImportReceipts(List<ImportReceiptModel> value) =>
      _save('import_receipts', value.map((item) => item.toJson()).toList());
  void saveExportReceipts(List<ExportReceiptModel> value) =>
      _save('export_receipts', value.map((item) => item.toJson()).toList());
  void saveLocations(List<WarehouseLocationModel> value) =>
      _save('locations', value.map((item) => item.toJson()).toList());
  void saveDamageReports(List<DamageReportModel> value) =>
      _save('damage_reports', value.map((item) => item.toJson()).toList());
  void saveInventoryChecks(List<InventoryCheckSession> value) =>
      _save('inventory_checks', value.map((item) => item.toJson()).toList());
  void saveInventorySnapshots(List<InventorySnapshotModel> value) => _save(
        'inventory_snapshots',
        value.map((item) => item.toJson()).toList(),
      );
  void saveAuth({
    required String email,
    required String passwordHash,
    required bool rememberedSession,
  }) {
    _saveValue('auth_email', email);
    _saveValue('password_hash', passwordHash);
    _saveValue('remembered_session', rememberedSession);
  }

  void saveUserProfile({
    required String name,
    required String role,
    String? avatarPath,
  }) {
    _saveValue('user_name', name);
    _saveValue('user_role', role);
    if (avatarPath != null) _saveValue('avatar_path', avatarPath);
  }

  Future<String?> loadAvatarPath(String uid) {
    return _loadValue<String>(_avatarKey(uid));
  }

  Future<String?> _loadAvatarForSnapshot(String? uid) async {
    final legacyPath = await _loadValue<String>('avatar_path');
    if (uid == null) return legacyPath;
    final userPath = await loadAvatarPath(uid);
    if (userPath != null || legacyPath == null) return userPath;

    // One-time compatibility bridge: attach the old single-device avatar to
    // the authenticated Firebase uid without uploading the path to Firestore.
    await _database.insert(
      'app_state',
      {
        'state_key': _avatarKey(uid),
        'payload': jsonEncode(legacyPath),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return legacyPath;
  }

  void saveAvatarPath(String uid, String? avatarPath) {
    final key = _avatarKey(uid);
    if (avatarPath == null || avatarPath.trim().isEmpty) {
      _deleteValue(key);
      return;
    }
    _saveValue(key, avatarPath);
  }

  String _avatarKey(String uid) => 'avatar_path_${uid.trim()}';

  void _saveValue(String key, Object value) {
    final payload = jsonEncode(value);
    _writeQueue = _writeQueue.then((_) async {
      await _database.insert(
        'app_state',
        {'state_key': key, 'payload': payload},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  void _save(String key, List<Map<String, Object?>> value) {
    final payload = jsonEncode(value);
    _writeQueue = _writeQueue.then((_) async {
      await _database.insert(
        'app_state',
        {'state_key': key, 'payload': payload},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  void _deleteValue(String key) {
    _writeQueue = _writeQueue.then((_) async {
      await _database.delete(
        'app_state',
        where: 'state_key = ?',
        whereArgs: [key],
      );
    });
  }

  Future<void> flush() => _writeQueue;

  Future<void> close() async {
    await flush();
    await _database.close();
  }
}
