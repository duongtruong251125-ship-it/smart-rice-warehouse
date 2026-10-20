import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/callable_inventory_transactions.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_batch_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';

void main() {
  final now = DateTime(2026, 10, 20);
  final batch = BatchModel(
      id: 'batch',
      code: 'LOT',
      riceId: 'rice',
      riceName: 'Rice',
      quantity: 10,
      importDate: now,
      manufactureDate: now,
      expiryDate: now.add(const Duration(days: 30)),
      status: BatchStatus.available);
  final export = ExportReceiptModel(
      id: 'export',
      code: 'PX001',
      customerId: 'customer',
      customerName: 'Customer',
      date: now,
      riceId: 'rice',
      riceName: 'Rice',
      quantity: 10,
      sellingPrice: 2,
      totalAmount: 20,
      note: '');

  test('adapter routes all four operations without trusting caller actor',
      () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repository =
        CallableInventoryTransactions(invoke: (name, payload) async {
      calls.add((name, payload));
    });
    await repository.confirmImportReceipt(
        receipt: ImportReceiptModel(
          id: 'import',
          code: 'PN001',
          supplierId: 'supplier',
          supplierName: 'Supplier',
          date: now,
          riceId: 'rice',
          riceName: 'Rice',
          quantity: 10,
          purchasePrice: 2,
          totalAmount: 20,
          batchCode: 'LOT',
          manufactureDate: now,
          expiryDate: batch.expiryDate,
        ),
        batchToCreateOrUpdate: batch,
        performedBy: 'forged');
    await repository.confirmExportReceipt(
        receipt: export, performedBy: 'forged');
    await repository.confirmDamageReport(
        report: DamageReportModel(
          id: 'damage',
          code: 'BH001',
          batchId: 'batch',
          batchCode: 'LOT',
          riceId: 'rice',
          riceName: 'Rice',
          quantity: 1,
          reason: DamageReason.moc,
          createdBy: 'display name only',
          createdAt: now,
        ),
        performedBy: 'forged');
    await repository.completeInventoryCheck(
        session: InventoryCheckSession(
          id: 'check',
          code: 'KK001',
          createdAt: now,
          createdBy: 'display name only',
          status: InventoryCheckStatus.completed,
        ),
        performedBy: 'forged');
    expect(calls.map((call) => call.$1),
        ['confirmImport', 'confirmExport', 'confirmDamage', 'completeCheck']);
    for (final call in calls) {
      expect(call.$2.containsKey('performedBy'), isFalse);
    }
    expect(calls[0].$2['batch']['id'], 'batch');
    expect(calls[1].$2['receipt']['date'], now.toUtc().toIso8601String());
    expect(
        calls[0].$2['batch']['manufactureDate'], now.toUtc().toIso8601String());
  });

  test('callable failures propagate and never fall back to local/direct writes',
      () async {
    for (final code in [
      'permission-denied',
      'unavailable',
      'not-found',
      'failed-precondition'
    ]) {
      var calls = 0;
      final repository =
          CallableInventoryTransactions(invoke: (name, payload) async {
        calls++;
        throw FirebaseFunctionsException(code: code, message: 'Server denied');
      });
      await expectLater(
          repository.confirmExportReceipt(
              receipt: export, performedBy: 'staff'),
          throwsA(isA<RepositoryException>()
              .having((error) => error.code, 'code', code)));
      expect(calls, 1);
    }
  });

  test('location writer patches only location without rewriting stale stock',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('batches').doc('batch').set({
      'quantity': 123,
      'remainingQuantity': 123,
      'riceId': 'rice',
      'code': 'LOT',
    });
    await FirestoreBatchRepository(firestore: db).moveBatch(
        batchId: 'batch', locationId: 'location', locationName: 'A1');
    final saved = (await db.collection('batches').doc('batch').get()).data()!;
    expect(saved['quantity'], 123);
    expect(saved['remainingQuantity'], 123);
    expect(saved['riceId'], 'rice');
    expect(saved['warehouseLocationId'], 'location');
    expect(saved.containsKey('status'), isFalse);
  });
}
