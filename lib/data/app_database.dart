import 'dart:async';
import 'dart:convert';

import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/models/inventory_snapshot_model.dart';
import 'package:sqflite/sqflite.dart';

class AppSnapshot {
  final List<InventorySnapshotModel> snapshots;
  const AppSnapshot({this.snapshots = const [], 
    this.rices,
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
    this.rememberedSession = false,
  });

  final List<RiceModel>? rices;
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
  final bool rememberedSession;
}

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;
  Future<void> _writeQueue = Future<void>.value();

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      '$root/smart_rice_warehouse.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE app_state (state_key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      ),
    );
    return AppDatabase._(database);
  }

  Future<AppSnapshot> loadSnapshot() async {
    return AppSnapshot(
      rices: await _load('rices', RiceModel.fromJson),
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
      authEmail: await _loadValue<String>('auth_email'),
      passwordHash: await _loadValue<String>('password_hash'),
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
  void saveAuth({
    required String email,
    required String passwordHash,
    required bool rememberedSession,
  }) {
    _saveValue('auth_email', email);
    _saveValue('password_hash', passwordHash);
    _saveValue('remembered_session', rememberedSession);
  }

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

  Future<void> flush() => _writeQueue;
}
