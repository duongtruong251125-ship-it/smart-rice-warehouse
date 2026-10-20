import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_rice_warehouse/data/firebase/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/firebase/firebase_data_migration_service.dart';
import 'package:smart_rice_warehouse/data/local/app_database.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_collection_repository.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_data_mode.dart';
import 'package:smart_rice_warehouse/logic/services/cloud_refresh_service.dart';
import 'auth_security_regression_test.dart'
    show TestAuth, TestProfiles, identity, activeAdmin;

void main() {
  setUpAll(sqfliteFfiInit);
  Future<AppDatabase> memory() => AppDatabase.open(
      factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath);
  Future<void> flushEvents() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('data mode is explicit and Firebase failure never selects local', () {
    expect(
        WarehouseDataMode.resolve(
            demoMode: false, useFirebaseBackend: true, firebaseReady: true),
        WarehouseDataMode.cloud);
    expect(
        () => WarehouseDataMode.resolve(
            demoMode: false, useFirebaseBackend: true, firebaseReady: false),
        throwsStateError);
    expect(
        WarehouseDataMode.resolve(
            demoMode: true, useFirebaseBackend: true, firebaseReady: false),
        WarehouseDataMode.demo);
    expect(
        WarehouseDataMode.resolve(
            demoMode: false, useFirebaseBackend: false, firebaseReady: true),
        WarehouseDataMode.local);
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
          const SyncSourceSnapshot(usesFirestore: true, isLoading: false)
        ]);
    expect(status.state, WarehouseSyncState.synced);
  });

  test('Firestore business stream resumes fresh data after background pause',
      () async {
    final db = FakeFirebaseFirestore();
    final policy = BusinessSyncPolicy(backgroundSyncEnabled: false);
    final repository = FirestoreCollectionRepository<BatchModel>(
        firestore: db,
        collectionPath: 'batches',
        mapper: const BatchMapper(),
        syncPolicy: policy);
    final values = <List<BatchModel>>[];
    final sub = repository.watchAll().listen(values.add);
    addTearDown(() async {
      await sub.cancel();
      policy.dispose();
    });
    await flushEvents();
    policy.configure(foreground: false);
    await flushEvents();
    final count = values.length;
    final batch = MockData.batches.first.copyWith(quantity: 55);
    await db
        .collection('batches')
        .doc(batch.id)
        .set(const BatchMapper().toFirestore(batch, null));
    await flushEvents();
    expect(values, hasLength(count));
    policy.configure(foreground: true);
    await flushEvents();
    expect(values.last.single.quantity, 55);
  });

  test(
      'migration manifest retains old sample IDs as real, excludes auth and file paths',
      () {
    final data = FirebaseDataMigrationService.manifest(AppSnapshot(
        batches: MockData.batches,
        rices: MockData.rices,
        authEmail: 'private',
        passwordHash: 'secret'));
    final encoded = jsonEncode(data);
    expect(encoded, contains(MockData.batches.first.id));
    expect(encoded, isNot(contains('secret')));
    expect(encoded, isNot(contains('imagePath')));
    expect(data['approvedLegacyData'], isTrue);
  });

  for (final active in [false, true]) {
    test(
        'migration ${active ? 'resumes safely after failure' : 'rejects an inactive admin before reading SQLite'}',
        () async {
      final auth = TestAuth()..user = identity;
      final profiles = TestProfiles();
      profiles.profiles[identity.uid] = activeAdmin.copyWith(isActive: active);
      addTearDown(auth.close);
      addTearDown(profiles.close);
      var calls = 0;
      var loads = 0;
      final service = FirebaseDataMigrationService(
          authentication: auth,
          profiles: profiles,
          loadLegacySnapshot: () async {
            loads++;
            return AppSnapshot(batches: MockData.batches.take(2).toList());
          },
          invoke: (_) async {
            calls++;
            if (calls == 1) return {'nextIndex': 1, 'status': 'in_progress'};
            if (calls == 2) throw StateError('network lost');
            return {
              'nextIndex': 2,
              'status': 'completed',
              'inserted': 2,
              'skipped': 0
            };
          });
      final result = await service.runMigration();
      if (!active) {
        expect(result.isFailure, isTrue);
        expect(loads, 0);
        expect(calls, 0);
      } else {
        expect(result.isPartial, isTrue);
        expect((await service.runMigration()).isSuccess, isTrue);
      }
    });
  }

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
