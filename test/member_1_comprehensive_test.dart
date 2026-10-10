import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/screens/batch/batch_detail_screen.dart';
import 'package:smart_rice_warehouse/screens/damage/damage_form_screen.dart';
import 'package:smart_rice_warehouse/screens/damage/damage_list_screen.dart';
import 'package:smart_rice_warehouse/screens/inventory_check/inventory_check_screen.dart';
import 'package:smart_rice_warehouse/screens/warehouse/warehouse_location_screen.dart';
import 'package:smart_rice_warehouse/services/qr_service.dart';
import 'package:smart_rice_warehouse/services/warehouse_service.dart';

Widget createTestApp(
  Widget child, {
  BatchProvider? batchProvider,
  WarehouseProvider? warehouseProvider,
  InventoryCheckProvider? checkProvider,
  DamageProvider? damageProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<RiceProvider>(create: (_) => RiceProvider()),
      ChangeNotifierProvider<BatchProvider>(create: (_) => batchProvider ?? BatchProvider()),
      ChangeNotifierProvider<WarehouseProvider>(create: (_) => warehouseProvider ?? WarehouseProvider()),
      ChangeNotifierProvider<InventoryCheckProvider>(create: (_) => checkProvider ?? InventoryCheckProvider()),
      ChangeNotifierProvider<DamageProvider>(create: (_) => damageProvider ?? DamageProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Member 1 - Task 1: QR & Warehouse Location Services & Models', () {
    test('QRService generates stable parseable payload and parses correctly', () {
      final batch = BatchModel(
        id: 'B001',
        code: 'ST25-2026-001',
        riceId: 'R001',
        riceName: 'Gạo ST25',
        quantity: 100,
        importDate: DateTime.now(),
        manufactureDate: DateTime.now().subtract(const Duration(days: 10)),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      final payload = QrService.generateBatchQrPayload(batchCode: batch.code, batchId: batch.id);
      expect(payload, 'ST25-2026-001');

      final parsed = QrService.parseBatchQr(payload);
      expect(parsed.isValid, isTrue);
      expect(parsed.batchCode, 'ST25-2026-001');
    });

    test('QRService parses JSON format, prefixed codes and raw strings', () {
      final jsonParsed = QrService.parseBatchQr('{"batchCode": "ST25-2026-001", "batchId": "B001"}');
      expect(jsonParsed.isValid, isTrue);
      expect(jsonParsed.batchCode, 'ST25-2026-001');
      expect(jsonParsed.batchId, 'B001');

      final prefixed = QrService.parseBatchQr('BATCH:ST25-2026-001');
      expect(prefixed.isValid, isTrue);
      expect(prefixed.batchCode, 'ST25-2026-001');

      final raw = QrService.parseBatchQr('ST25-2026-001');
      expect(raw.isValid, isTrue);
      expect(raw.batchCode, 'ST25-2026-001');

      final invalid = QrService.parseBatchQr('   ');
      expect(invalid.isValid, isFalse);
    });

    test('WarehouseService correctly calculates location usage and availability', () {
      const loc = WarehouseLocationModel(
        id: 'LOC-A1-1',
        zone: 'Khu A',
        rack: 'Kệ 1',
        shelf: 'Tầng 1',
        code: 'A-K1-T1',
        capacity: 1000,
        currentBatchCount: 1,
      );

      final batch = BatchModel(
        id: 'B001',
        code: 'ST25-2026-001',
        riceId: 'R001',
        riceName: 'Gạo ST25',
        quantity: 800,
        importDate: DateTime.now(),
        manufactureDate: DateTime.now().subtract(const Duration(days: 10)),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        status: BatchStatus.available,
        warehouseLocationId: 'LOC-A1-1',
      );

      final usage = WarehouseService.calculateLocationUsage(
        locations: [loc],
        batches: [batch],
      );

      expect(usage['LOC-A1-1']?.batchCount, 1);
      expect(usage['LOC-A1-1']?.totalWeight, 800.0);

      // Sức chứa 1000kg, đã dùng 800kg, yêu cầu thêm 150kg -> Khả dụng
      final available150 = WarehouseService.findAvailableLocations(
        locations: [loc],
        batches: [batch],
        requiredCapacity: 150,
      );
      expect(available150.length, 1);

      // Sức chứa 1000kg, đã dùng 800kg, yêu cầu thêm 250kg -> Không khả dụng
      final available250 = WarehouseService.findAvailableLocations(
        locations: [loc],
        batches: [batch],
        requiredCapacity: 250,
      );
      expect(available250, isEmpty);
    });

    test('Location assignment updates batch location without changing quantity', () {
      final batchProvider = BatchProvider();
      final initialBatch = batchProvider.batches.first;
      final initialQuantity = initialBatch.quantity;

      final success = batchProvider.assignLocation(
        batchId: initialBatch.id,
        locationId: 'loc-a-02',
        locationName: 'Khu A → Kệ 1 → Tầng 2 (A-K1-T2)',
      );

      expect(success, isTrue);
      final updated = batchProvider.findById(initialBatch.id)!;
      expect(updated.warehouseLocationId, 'loc-a-02');
      expect(updated.locationName, 'Khu A → Kệ 1 → Tầng 2 (A-K1-T2)');
      expect(updated.quantity, initialQuantity); // Quan trọng: quantity không đổi
    });
  });

  group('Member 1 - Task 2: Inventory Check Workflow', () {
    test('Session tracks expected vs actual with accurate difference and requires reason on diff', () {
      final checkProvider = InventoryCheckProvider();
      final session = checkProvider.startNewSession(createdBy: 'Thủ kho');

      expect(session.status, InventoryCheckStatus.inProgress);
      expect(session.items, isEmpty);

      final batch1 = BatchModel(
        id: 'B001',
        code: 'ST25-2026-001',
        riceId: 'R001',
        riceName: 'Gạo ST25',
        quantity: 50.0,
        importDate: DateTime.now(),
        manufactureDate: DateTime.now().subtract(const Duration(days: 10)),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      // System = 50, Actual = 47 -> Diff = -3
      checkProvider.addOrUpdateItem(
        batch: batch1,
        actualQuantity: 47.0,
        reason: InventoryCheckReason.haoHut,
        note: 'Hao hụt tự nhiên do bay hơi ẩm',
      );

      final itemWithDiff = checkProvider.activeSession!.items.first;
      expect(itemWithDiff.difference, -3.0);
      expect(itemWithDiff.reason, InventoryCheckReason.haoHut);
      expect(checkProvider.activeSession!.totalDifference, -3.0);

      final batch2 = BatchModel(
        id: 'B002',
        code: 'ST25-2026-002',
        riceId: 'R001',
        riceName: 'Gạo ST25',
        quantity: 20.0,
        importDate: DateTime.now(),
        manufactureDate: DateTime.now().subtract(const Duration(days: 10)),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        status: BatchStatus.available,
      );

      // System = 20, Actual = 20 -> Diff = 0 -> Reason None
      checkProvider.addOrUpdateItem(
        batch: batch2,
        actualQuantity: 20.0,
      );

      final itemZeroDiff = checkProvider.activeSession!.items.firstWhere((i) => i.batchId == 'B002');
      expect(itemZeroDiff.difference, 0.0);
      expect(itemZeroDiff.reason, InventoryCheckReason.none);
    });

    test('Completing inventory check session accurately adjusts batch quantities', () {
      final batchProvider = BatchProvider();
      final checkProvider = InventoryCheckProvider();

      final targetBatch = batchProvider.batches.first;
      const actualCount = 85.0; // Assume new count

      checkProvider.startNewSession(createdBy: 'Thủ kho');
      checkProvider.addOrUpdateItem(
        batch: targetBatch,
        actualQuantity: actualCount,
        reason: InventoryCheckReason.saiDuLieu,
      );

      final completed = checkProvider.completeSession(batchProvider: batchProvider);

      expect(completed, isTrue);
      expect(checkProvider.activeSession, isNull);

      final adjustedBatch = batchProvider.findById(targetBatch.id)!;
      expect(adjustedBatch.quantity, actualCount);
    });
  });

  group('Member 1 - Task 3: Damage Reporting Workflow', () {
    test('Validation prevents reporting quantity > available or <= 0', () {
      final damageProvider = DamageProvider();
      final batchProvider = BatchProvider();
      final batch = batchProvider.batches.first;

      // Quantity <= 0
      final resultZero = damageProvider.createDamageReport(
        batchId: batch.id,
        batchCode: batch.code,
        riceId: batch.riceId,
        riceName: batch.riceName,
        quantity: 0,
        reason: DamageReason.baoRach,
        batchProvider: batchProvider,
      );
      expect(resultZero, isFalse);

      // Quantity > Available
      final resultExcess = damageProvider.createDamageReport(
        batchId: batch.id,
        batchCode: batch.code,
        riceId: batch.riceId,
        riceName: batch.riceName,
        quantity: batch.quantity + 500,
        reason: DamageReason.baoRach,
        batchProvider: batchProvider,
      );
      expect(resultExcess, isFalse);
    });

    test('Damage report reduces available batch stock and records history without going below 0', () {
      final damageProvider = DamageProvider();
      final batchProvider = BatchProvider();
      final targetBatch = batchProvider.batches.first;
      final initialStock = targetBatch.quantity;
      const damageQty = 15.0;

      final success = damageProvider.createDamageReport(
        batchId: targetBatch.id,
        batchCode: targetBatch.code,
        riceId: targetBatch.riceId,
        riceName: targetBatch.riceName,
        quantity: damageQty,
        reason: DamageReason.moc,
        batchProvider: batchProvider,
        note: 'Bao bì ẩm mốc do dột mái kho',
      );

      expect(success, isTrue);

      final updatedBatch = batchProvider.findById(targetBatch.id)!;
      expect(updatedBatch.quantity, initialStock - damageQty);
      expect(updatedBatch.quantity, greaterThanOrEqualTo(0));

      final reportsByReason = damageProvider.filter(reason: DamageReason.moc);
      expect(reportsByReason.isNotEmpty, isTrue);
      expect(reportsByReason.first.reason, DamageReason.moc);
    });
  });

  group('Member 1 - Responsive UI Tests (320px narrow mobile)', () {
    testWidgets('BatchDetailScreen renders at 320x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testBatch = MockData.batches.first;
      await tester.pumpWidget(createTestApp(BatchDetailScreen(batchId: testBatch.id)));
      await tester.pumpAndSettle();

      expect(find.text('Lô: ${testBatch.code}'), findsOneWidget);
      expect(find.text('Mã QR Lô hàng'), findsOneWidget);
      expect(find.text('Vị trí lưu kho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WarehouseLocationScreen renders at 320x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const WarehouseLocationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vị trí kho lưu trữ'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('InventoryCheckScreen renders at 320x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const InventoryCheckScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kiểm kê'), findsWidgets);
      expect(find.text('Quét QR Lô'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DamageFormScreen renders at 320x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testBatch = MockData.batches.first;
      await tester.pumpWidget(createTestApp(DamageFormScreen(initialBatch: testBatch)));
      await tester.pumpAndSettle();

      expect(find.text('Lập phiếu báo hỏng gạo'), findsOneWidget);
      expect(find.text('Xác nhận báo hỏng & Giảm tồn kho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DamageListScreen renders at 320x640 without overflow and displays history', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const DamageListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sổ báo hỏng gạo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
