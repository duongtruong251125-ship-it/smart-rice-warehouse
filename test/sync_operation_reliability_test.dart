import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_collection_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/restarting_repository_stream.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/warehouse_location_mapper.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/batch_location_writer.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/services/catalog_form_service.dart';
import 'package:smart_rice_warehouse/presentation/screens/batch/batch_detail_screen.dart';
import 'package:smart_rice_warehouse/presentation/widgets/add_warehouse_location_dialog.dart';

class WriteRepository<T> extends Fake implements CrudRepository<T> {
  WriteRepository(this.initial);
  final List<T> initial;
  final sources = <StreamController<List<T>>>[];
  Completer<void> gate = Completer<void>();
  Completer<void>? cancelGate;
  int writes = 0;
  int active = 0;
  int maximum = 0;
  @override
  Stream<List<T>> watchAll() {
    final index = sources.length;
    late StreamController<List<T>> controller;
    controller = StreamController<List<T>>(onListen: () {
      active++;
      if (active > maximum) maximum = active;
      controller.add(initial);
    }, onCancel: () async {
      if (index == 0) await cancelGate?.future;
      active--;
    });
    sources.add(controller);
    return controller.stream;
  }

  @override
  Future<void> create(String id, T value) async {
    writes++;
    await gate.future;
  }

  Future<void> close() async {
    if (cancelGate?.isCompleted == false) cancelGate!.complete();
    for (final source in sources) {
      await source.close();
    }
  }
}

class MoveRepository extends WriteRepository<BatchModel>
    implements BatchLocationWriter {
  MoveRepository(super.initial);
  @override
  Future<void> moveBatch(
      {required String batchId,
      required String locationId,
      required String locationName}) async {
    writes++;
    await gate.future;
  }
}

class BrokenLocationMapper extends WarehouseLocationMapper {
  const BrokenLocationMapper(this.error);
  final Object error;
  @override
  WarehouseLocationModel fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> snapshot,
          SnapshotOptions? options) =>
      throw error;
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const location = WarehouseLocationModel(
    id: 'target',
    code: 'A1',
    zone: 'A',
    rack: '1',
    shelf: '1',
    capacity: 100000,
    currentBatchCount: 0);

void main() {
  for (final code in ['permission-denied', 'unavailable']) {
    test(
        'repository maps $code and provider exits loading with retry available',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('locations').doc('one').set({'code': 'A1'});
      final repository = FirestoreCollectionRepository<WarehouseLocationModel>(
          firestore: db,
          collectionPath: 'locations',
          mapper: BrokenLocationMapper(
              FirebaseException(plugin: 'cloud_firestore', code: code)));
      final provider = WarehouseProvider(initial: [], repository: repository);
      addTearDown(provider.dispose);
      final documentErrors = <Object>[];
      final documentSub = repository
          .watchById('one')
          .listen((_) {}, onError: documentErrors.add);
      addTearDown(documentSub.cancel);
      await flush();
      expect(provider.isLoading, isFalse);
      expect(provider.lastFailure?.code, code);
      expect(provider.lastFailure?.cause, isA<FirebaseException>());
      expect(
          documentErrors.single,
          isA<RepositoryException>()
              .having((error) => error.code, 'code', code));
      provider.retrySync();
      await flush();
      expect(provider.lastFailure?.code, code);
    });
  }

  test(
      'replacement waits for cancellation; reconnect bursts have only one source',
      () async {
    final signals = StreamController<Object?>.broadcast();
    final gate = Completer<void>();
    final sources = <StreamController<int>>[];
    final values = <int>[];
    var active = 0;
    var maximum = 0;
    final stream = restartingRepositoryStream<int>(
        reconnect: signals.stream,
        mapError: (error) => error,
        open: () {
          final first = sources.isEmpty;
          late StreamController<int> source;
          source = StreamController<int>(onListen: () {
            active++;
            if (active > maximum) maximum = active;
          }, onCancel: () async {
            if (first) await gate.future;
            active--;
          });
          sources.add(source);
          return source.stream;
        });
    final sub = stream.listen(values.add);
    await flush();
    sources.first.add(1);
    await flush();
    signals.add('login');
    signals.add('reconnect');
    signals.add('login-again');
    await flush();
    expect(sources, hasLength(1));
    sources.first.add(999);
    await flush();
    expect(values, [1]);
    gate.complete();
    await flush();
    expect(sources, hasLength(2));
    expect(maximum, 1);
    sources.last.add(2);
    await flush();
    expect(values, [1, 2]);
    await sub.cancel();
    await signals.close();
    for (final source in sources) {
      await source.close();
    }
  });

  test(
      'manual provider retry is serialized and old stream cannot replace current data',
      () async {
    final repo = WriteRepository<WarehouseLocationModel>([location])
      ..cancelGate = Completer<void>();
    final provider = WarehouseProvider(repository: repo);
    await flush();
    provider.retrySync();
    provider.retrySync();
    await flush();
    expect(repo.sources, hasLength(1));
    repo.cancelGate!.complete();
    await flush();
    expect(repo.maximum, 1);
    expect(repo.sources, hasLength(2));
    repo.sources.last.add([location.copyWith(code: 'NEW')]);
    await flush();
    repo.sources.first.add([location.copyWith(code: 'STALE')]);
    await flush();
    expect(provider.locations.single.code, 'NEW');
    provider.dispose();
    await repo.close();
  });

  test(
      'add location waits, rejects duplicates, preserves state on failure and can retry',
      () async {
    final repo = WriteRepository<WarehouseLocationModel>([]);
    final provider = WarehouseProvider(initial: [], repository: repo);
    await flush();
    final first = provider.addLocationOnline(location);
    expect(provider.isSavingLocation, isTrue);
    expect(await provider.addLocationOnline(location), isFalse);
    expect(repo.writes, 1);
    expect(provider.locations, isEmpty);
    repo.gate.completeError(
        const RepositoryException('No permission', code: 'permission-denied'));
    expect(await first, isFalse);
    expect(provider.lastFailure?.code, 'permission-denied');
    expect(provider.locations, isEmpty);
    repo.gate = Completer<void>();
    final retry = provider.addLocationOnline(location);
    repo.gate.complete();
    expect(await retry, isTrue);
    repo.sources.last.add([location]);
    await flush();
    expect(provider.locations.single.id, 'target');
    provider.dispose();
    await repo.close();
  });

  test(
      'cloud move waits for acknowledgement and counts follow confirmed batch snapshots',
      () async {
    final batch = MockData.batches.first
        .copyWith(quantity: 10, warehouseLocationId: 'old');
    final repo = MoveRepository([batch]);
    final batches = BatchProvider(initial: [batch], repository: repo);
    final warehouse = WarehouseProvider(initial: [location]);
    await flush();
    final first = CatalogFormService().assignBatchLocation(
        warehouseProvider: warehouse,
        batchProvider: batches,
        batch: batch,
        locationId: location.id);
    expect(repo.writes, 1);
    expect(warehouse.locations.single.currentBatchCount, 0);
    expect(
        await batches.assignLocationOnline(
            batchId: batch.id, locationId: location.id, locationName: 'A1'),
        isFalse);
    repo.gate.completeError(
        const RepositoryException('network', code: 'unavailable'));
    expect((await first).success, isFalse);
    expect(batches.findById(batch.id)!.warehouseLocationId, 'old');
    expect(warehouse.locations.single.currentBatchCount, 0);
    repo.gate = Completer<void>();
    final retry = CatalogFormService().assignBatchLocation(
        warehouseProvider: warehouse,
        batchProvider: batches,
        batch: batch,
        locationId: location.id);
    repo.gate.complete();
    expect((await retry).success, isTrue);
    repo.sources.last.add([batch.copyWith(warehouseLocationId: location.id)]);
    await flush();
    expect(warehouse.locations.single.currentBatchCount, 1);
    warehouse.dispose();
    batches.dispose();
    await repo.close();
  });

  test(
      'dispose during writes and listener cancellation causes no late notification',
      () async {
    final repo = WriteRepository<WarehouseLocationModel>([]);
    final provider = WarehouseProvider(initial: [], repository: repo);
    await flush();
    final save = provider.addLocationOnline(location);
    provider.dispose();
    repo.gate.completeError(StateError('late server failure'));
    expect(await save, isFalse);
    expect(provider.errorMessage, isNull);
    await repo.close();
    final moveRepo = MoveRepository([MockData.batches.first]);
    final batches =
        BatchProvider(initial: moveRepo.initial, repository: moveRepo);
    await flush();
    final move = batches.assignLocationOnline(
        batchId: moveRepo.initial.first.id,
        locationId: 'target',
        locationName: 'A1');
    batches.dispose();
    moveRepo.gate.complete();
    expect(await move, isTrue);
    await moveRepo.close();
  });

  test(
      'manual sync catches thrown server errors, blocks duplicate submits and tolerates dispose',
      () async {
    final gate = Completer<({bool success, String? message})>();
    var calls = 0;
    final auth = AuthProvider(
        demoMode: true,
        onForceCloudSync: () {
          calls++;
          return gate.future;
        });
    final sync = auth.triggerCloudSync();
    expect((await auth.triggerCloudSync()).success, isFalse);
    expect(calls, 1);
    auth.dispose();
    gate.completeError(StateError('server offline'));
    expect((await sync).success, isFalse);
  });

  testWidgets(
      'add dialog stays open while pending, keeps input after failure and closes only on success',
      (tester) async {
    final repo = WriteRepository<WarehouseLocationModel>([]);
    final provider = WarehouseProvider(initial: [], repository: repo);
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<String>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              AddWarehouseLocationDialog(provider: provider));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu vị trí'));
    await tester.tap(find.text('Lưu vị trí'));
    await tester.pump();
    expect(find.text('Đang lưu...'), findsOneWidget);
    expect(result, isNull);
    expect(repo.writes, 1);
    repo.gate.completeError(const RepositoryException('permission denied',
        code: 'permission-denied'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-save-error')), findsOneWidget);
    expect(find.text('A-K3-T1'), findsOneWidget);
    expect(result, isNull);
    repo.gate = Completer<void>();
    await tester.tap(find.text('Lưu vị trí'));
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(result, 'A-K3-T1');
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    await tester.pump();
    expect(repo.active, 0);
    addTearDown(repo.close);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'removing a dialog during a pending save ignores the late failure',
      (tester) async {
    final repo = WriteRepository<WarehouseLocationModel>([]);
    final provider = WarehouseProvider(initial: [], repository: repo);
    await tester.pumpWidget(
        MaterialApp(home: AddWarehouseLocationDialog(provider: provider)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu vị trí'));
    await tester.pump();
    expect(repo.writes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    repo.gate.completeError(
        const RepositoryException('late network error', code: 'unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    addTearDown(repo.close);
  });

  testWidgets(
      'move sheet preserves selection on failure and waits for successful retry',
      (tester) async {
    final batch = MockData.batches.first
        .copyWith(quantity: 10, warehouseLocationId: 'old');
    final repo = MoveRepository([batch]);
    final batches = BatchProvider(initial: [batch], repository: repo);
    final warehouse = WarehouseProvider(initial: [location]);
    final rices = RiceProvider(initial: MockData.rices);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: batches),
      ChangeNotifierProvider.value(value: warehouse),
      ChangeNotifierProvider.value(value: rices),
    ], child: MaterialApp(home: BatchDetailScreen(batchId: batch.id))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đổi vị trí'));
    await tester.tap(find.text('Đổi vị trí'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(location.fullDisplayName));
    await tester.pump();
    await tester.tap(find.text('Xác nhận chuyển vị trí'));
    await tester.tap(find.text('Xác nhận chuyển vị trí'));
    await tester.pump();
    expect(find.text('Đang chuyển...'), findsOneWidget);
    expect(repo.writes, 1);
    repo.gate.completeError(
        const RepositoryException('network', code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-move-error')), findsOneWidget);
    repo.gate = Completer<void>();
    await tester.tap(find.text('Xác nhận chuyển vị trí'));
    await tester.pump();
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Chuyển vị trí kho lưu trữ'), findsNothing);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    warehouse.dispose();
    batches.dispose();
    rices.dispose();
    await tester.pump();
    expect(repo.active, 0);
    addTearDown(repo.close);
    expect(tester.takeException(), isNull);
  });
}
