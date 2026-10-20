import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/services/damage_form_service.dart';
import 'package:smart_rice_warehouse/logic/services/inventory_form_service.dart';
import 'package:smart_rice_warehouse/logic/services/report_service.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';
import 'package:smart_rice_warehouse/logic/view_models/login_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/reports_view_model.dart';

void main() {
  final rice = MockData.rices.first;
  final supplier = MockData.suppliers.first;
  final customer = MockData.customers.first;
  ImportReceiptModel imported(String id, DateTime date, double quantity) =>
      ImportReceiptModel(
          id: id,
          code: id,
          supplierId: supplier.id,
          supplierName: supplier.name,
          date: date,
          riceId: rice.id,
          riceName: rice.name,
          quantity: quantity,
          purchasePrice: 10,
          totalAmount: quantity * 10,
          batchCode: id,
          manufactureDate: date,
          expiryDate: date.add(const Duration(days: 365)));

  test('report logic separates calendar months and fills seven missing days',
      () {
    final date = DateTime(2026, 10, 19);
    final data = ReportsViewModel(
        date: date,
        imports: [
          imported('previous-month', DateTime(2026, 9, 30), 900),
          imported('previous-year', DateTime(2025, 10, 19), 800),
          imported('week1', DateTime(2026, 10, 7), 3),
          imported('today', date, 2),
        ],
        exports: [],
        batches: [],
        rices: [rice],
        snapshots: [],
        inventoryValue: 0,
        totalStock: 0);
    expect(data.monthImportQuantity, 5);
    expect(data.monthImportAmount, 50);
    expect(data.monthImports.length, 2);
    expect(data.activities.length, 7);
    expect(data.activities.first.date, DateTime(2026, 10, 13));
    expect(data.activities.first.importQuantity, 0);
    expect(data.activities.last.importQuantity, 2);
    expect(data.total7DaysImport, 2);
    expect(data.weeklyData.map((item) => item.importQty), [3, 0, 2, 0]);
  });

  test('inventory composition excludes expired batches and preserves snapshots',
      () {
    final date = DateTime(2026, 10, 19);
    BatchModel batch(String id, DateTime expiry, double quantity) => BatchModel(
        id: id,
        code: id,
        riceId: rice.id,
        riceName: rice.name,
        quantity: quantity,
        importDate: date,
        manufactureDate: date,
        expiryDate: expiry,
        status: BatchStatus.available);
    final slices = buildInventorySlices(batches: [
      batch('available', date, 4),
      batch('expired', date.subtract(const Duration(days: 1)), 999),
      batch('empty', date.add(const Duration(days: 1)), 0),
    ], rices: [
      rice
    ], today: date);
    expect(slices.single.quantity, 4);
    final points = buildInventoryValuePoints(
        snapshots: [
          InventorySnapshotModel(
              id: 1,
              date: date.subtract(const Duration(days: 1)),
              totalQuantity: 1,
              totalValue: 123),
        ],
        today: date,
        currentValue: 50,
        importReceipts: [],
        exportReceipts: [],
        rices: [rice]);
    expect(points[5].value, 123);
    expect(points.last.value, 50);
  });

  test('form service imports and exports through FEFO without a widget tree',
      () async {
    final now = DateTime.now();
    final batches = BatchProvider(initial: []);
    final imports = ImportProvider(batches, initial: []);
    final exports = ExportProvider(batches, initial: []);
    addTearDown(batches.dispose);
    addTearDown(imports.dispose);
    addTearDown(exports.dispose);
    var id = 0;
    final service =
        InventoryFormService(clock: () => now, newId: () => 'doc-${++id}');
    expect(
        await service.submitImport(
            provider: imports,
            supplier: supplier,
            rice: rice,
            quantity: 100,
            purchasePrice: 10,
            batchCode: 'LOT1',
            manufactureDate: now,
            expiryDate: now.add(const Duration(days: 100))),
        isTrue);
    expect(imports.receipts.single.totalAmount, 1000);
    expect(imports.receipts.single.id, batches.batches.single.id);
    final allocation =
        exports.previewFefoAllocation(riceId: rice.id, quantity: 30);
    expect(allocation.isSuccess, isTrue);
    expect(
        await service.submitExport(
            provider: exports,
            customer: customer,
            rice: rice,
            quantity: 30,
            sellingPrice: 20,
            allocations: allocation.allocations,
            note: '  test  '),
        isTrue);
    expect(exports.receipts.single.totalAmount, 600);
    expect(exports.receipts.single.note, 'test');
    expect(batches.totalStockForRice(rice.id), 70);
    final over = exports.previewFefoAllocation(riceId: rice.id, quantity: 71);
    expect(over.isSuccess, isFalse);
    expect(batches.totalStockForRice(rice.id), 70);
  });

  test('damage logic rejects invalid quantities without changing inventory',
      () async {
    final now = DateTime.now();
    final batch = BatchModel(
        id: 'b',
        code: 'B',
        riceId: rice.id,
        riceName: rice.name,
        quantity: 10,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 30)),
        status: BatchStatus.available);
    final batches = BatchProvider(initial: [batch]);
    final damages = DamageProvider(initial: []);
    addTearDown(batches.dispose);
    addTearDown(damages.dispose);
    for (final value in ['NaN', '-1', '11']) {
      final result = await DamageFormService().submit(
          batch: batch,
          batches: batches,
          damages: damages,
          quantityText: value,
          reason: DamageReason.baoRach,
          note: '');
      expect(result.success, isFalse);
    }
    expect(batches.batches.single.quantity, 10);
    expect(damages.reports, isEmpty);
  });

  test(
      'login view model preserves local authentication and rejects bad credentials',
      () async {
    final auth = AuthProvider(demoMode: true);
    addTearDown(auth.dispose);
    final vm = LoginViewModel(auth);
    expect(
        (await vm.signIn(
                email: 'admin@gmail.com',
                password: 'incorrect',
                remember: false))
            .success,
        isFalse);
    expect(
        (await vm.signIn(
                email: ' admin@gmail.com ', password: '123456', remember: true))
            .success,
        isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(FormValidators.number('NaN', 'Số lượng', positive: true), isNotNull);
    expect(FormValidators.number('0', 'Số lượng', positive: true), isNotNull);
    expect(FormValidators.parseNumber(' 1,5 '), 1.5);
  });
}
