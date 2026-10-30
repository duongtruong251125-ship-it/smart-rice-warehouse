import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_rice_warehouse/data/sync/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/local/app_database.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_data_mode.dart';
import 'package:smart_rice_warehouse/logic/services/cloud_refresh_service.dart';
import 'auth_security_regression_test.dart'
    show TestAuth, TestProfiles, identity, activeAdmin;

void main() {
  setUpAll(sqfliteFfiInit);
  Future<AppDatabase> memory() => AppDatabase.open(
      factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath);
  test('data mode selects Supabase for production and demo only by request',
      () {
    expect(WarehouseDataMode.resolve(demoMode: false, supabaseReady: true),
        WarehouseDataMode.cloud);
    expect(
        () => WarehouseDataMode.resolve(demoMode: false, supabaseReady: false),
        throwsStateError);
    expect(WarehouseDataMode.resolve(demoMode: true, supabaseReady: false),
        WarehouseDataMode.demo);
    expect(WarehouseDataMode.values.map((mode) => mode.databaseName).toSet(),
        hasLength(3));
    expect(WarehouseDataMode.local.databaseName, 'smart_rice_warehouse.db');
  });

  test('fresh real/local/cache DB stays empty; only explicit demo seeds once',
      () async {
    final db = await memory();
    addTearDown(db.close);
    expect(await db.seedLocalDataIfNeeded(), isFalse);
    expect((await db.loadSnapshot()).batches, isNull);
    expect(await db.seedLocalDataIfNeeded(demoMode: true), isTrue);
    expect((await db.loadSnapshot()).batches, isNotEmpty);
    expect(await db.seedLocalDataIfNeeded(demoMode: true), isFalse);
  });

  test(
      'old DB without marker is preserved in real mode without recognizing sample IDs',
      () async {
    final db = await memory();
    addTearDown(db.close);
    final original = MockData.batches.first.copyWith(quantity: 1234);
    db.saveBatches([original]);
    await db.flush();
    expect(await db.seedLocalDataIfNeeded(), isFalse);
    final loaded = (await db.loadSnapshot()).batches!;
    expect(loaded, hasLength(1));
    expect(loaded.single.id, original.id);
    expect(loaded.single.quantity, 1234);
  });

  test('old seed version 3 is not upgraded/rewritten outside demo', () async {
    final raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) => db.execute(
                'CREATE TABLE app_state (state_key TEXT PRIMARY KEY, payload TEXT NOT NULL)')));
    await raw.insert(
        'app_state', {'state_key': 'local_seed_version', 'payload': '3'});
    final original = MockData.batches.first.toJson();
    await raw.insert('app_state', {
      'state_key': 'batches',
      'payload': jsonEncode([original])
    });
    // Shared in-memory handle lets the public AppDatabase path run real SQLite code.
    final db = await memory();
    addTearDown(db.close);
    expect(await db.seedLocalDataIfNeeded(), isFalse);
    expect(
        (await raw.query('app_state',
                where: 'state_key = ?', whereArgs: ['local_seed_version']))
            .single['payload'],
        '3');
    expect((await db.loadSnapshot()).batches!.single.id, original['id']);
  });

  test(
      'background toggle pauses only background listeners and never changes cloud state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.init();
    final policy = BusinessSyncPolicy();
    addTearDown(settings.dispose);
    addTearDown(policy.dispose);
    settings.addListener(
        () => policy.configure(backgroundSyncEnabled: settings.backgroundSync));
    await settings.setBackgroundSync(false);
    expect(policy.shouldListen, isTrue); // foreground always reads cloud
    policy.configure(foreground: false);
    expect(policy.shouldListen, isFalse);
    await settings.setBackgroundSync(true);
    expect(policy.shouldListen, isTrue);
    await settings.setBackgroundSync(false);
    expect(policy.shouldListen, isFalse);
    policy.configure(foreground: true);
    expect(policy.shouldListen, isTrue);
    final status = WarehouseSyncStatus.resolve(
        backgroundSyncEnabled: false,
        sources: [
          const SyncSourceSnapshot(usesCloudBackend: true, isLoading: false)
        ]);
    expect(status.state, WarehouseSyncState.synced);
  });

  test(
      'cloud refresh verifies profile and returns failure rather than uploading local data',
      () async {
    final auth = TestAuth()..user = identity;
    final profiles = TestProfiles();
    addTearDown(auth.close);
    addTearDown(profiles.close);
    var reads = 0;
    final service = CloudRefreshService(
        authentication: auth,
        profiles: profiles,
        refreshData: () async {
          reads++;
          throw StateError('network');
        });
    expect((await service.refresh()).success, isFalse);
    expect(reads, 1);
    profiles.profiles[identity.uid] = activeAdmin.copyWith(isActive: false);
    expect((await service.refresh()).success, isFalse);
    expect(reads, 1);
  });
}
