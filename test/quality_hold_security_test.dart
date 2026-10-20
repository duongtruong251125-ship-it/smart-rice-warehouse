import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/inventory_transaction_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/services/fefo_service.dart';
import 'package:smart_rice_warehouse/logic/services/stock_transaction_planner.dart';

void main() {
  final now = DateTime.now();
  final available = BatchModel(
    id: 'available',
    code: 'AVAILABLE',
    riceId: 'rice',
    riceName: 'Rice',
    quantity: 100,
    importDate: now,
    manufactureDate: now,
    expiryDate: now.add(const Duration(days: 60)),
    status: BatchStatus.available,
  );
  final held = available.copyWith(
    id: 'held',
    code: 'HELD',
    status: BatchStatus.qualityHold,
    expiryDate: now.add(const Duration(days: 30)),
  );
  BatchAllocation allocation(BatchModel batch) => BatchAllocation(
        batchId: batch.id,
        batchCode: batch.code,
        allocatedQuantity: 10,
        batchInitialQuantity: 100,
        batchRemainingQuantity: 90,
        expiryDate: batch.expiryDate,
      );
  ExportReceiptModel receipt(List<BatchModel> batches) => ExportReceiptModel(
        id: 'export',
        code: 'PX001',
        customerId: 'customer',
        customerName: 'Customer',
        date: now,
        riceId: 'rice',
        riceName: 'Rice',
        quantity: batches.length * 10,
        sellingPrice: 1,
        totalAmount: batches.length * 10,
        note: '',
        allocations: batches.map(allocation).toList(),
      );
  final unavailable = isA<RepositoryException>().having(
    (error) => error.code,
    'code',
    StockTransactionError.batchUnavailable,
  );

  test('FEFO skips held stock even when it expires first', () {
    final result = const FefoService().allocate(
      batches: [held, available],
      riceId: 'rice',
      quantity: 50,
      currentDate: now,
    );
    expect(result.isSuccess, isTrue);
    expect(result.allocations.single.batchId, available.id);
    expect(
        const FefoService().allocate(
          batches: [held],
          riceId: 'rice',
          quantity: 1,
          currentDate: now,
        ).isSuccess,
        isFalse);
  });

  test('available stock excludes held batches and local export is atomic', () {
    final provider = BatchProvider(initial: [held, available]);
    addTearDown(provider.dispose);
    expect(provider.totalStock, 100);
    expect(provider.totalStockForRice('rice'), 100);
    expect(
        provider
            .applyFefoAllocations([allocation(available), allocation(held)]),
        isFalse);
    expect(provider.findById(available.id)!.quantity, 100);
    expect(provider.findById(held.id)!.quantity, 100);
  });

  test('planner rejects supplied allocations to held stock', () {
    expect(
        () => const StockTransactionPlanner().planExport(
              receipt: receipt([available, held]),
              receiptExists: false,
              batchesById: {available.id: available, held.id: held},
              performedBy: 'staff',
              now: now,
            ),
        throwsA(unavailable));
  });

  test('transaction checks latest hold and writes no partial stock or receipt',
      () async {
    final db = FakeFirebaseFirestore();
    const mapper = BatchMapper();
    // The client preview was available; another operator held the batch later.
    final staleReceipt =
        receipt([available, held.copyWith(status: BatchStatus.available)]);
    for (final batch in [available, held]) {
      await db
          .collection('batches')
          .doc(batch.id)
          .set(mapper.toFirestore(batch, null));
    }
    final repository =
        InventoryTransactionRepository(firestore: db, clock: () => now);
    await expectLater(
        repository.confirmExportReceipt(
          receipt: staleReceipt,
          performedBy: 'staff',
        ),
        throwsA(unavailable));
    expect(
        (await db.collection('batches').doc(available.id).get())
            .data()!['quantity'],
        100);
    expect(
        (await db.collection('batches').doc(held.id).get()).data()!['quantity'],
        100);
    expect((await db.collection('export_receipts').get()).docs, isEmpty);
    expect((await db.collection('stock_movements').get()).docs, isEmpty);
  });

  test('valid multi-batch export still commits stock and movements together',
      () async {
    final second = held.copyWith(status: BatchStatus.lowStock);
    final db = FakeFirebaseFirestore();
    const mapper = BatchMapper();
    for (final batch in [available, second]) {
      await db
          .collection('batches')
          .doc(batch.id)
          .set(mapper.toFirestore(batch, null));
    }
    await InventoryTransactionRepository(firestore: db, clock: () => now)
        .confirmExportReceipt(
            receipt: receipt([available, second]), performedBy: 'staff');
    expect(
        (await db.collection('batches').doc(available.id).get())
            .data()!['quantity'],
        90);
    expect(
        (await db.collection('batches').doc(second.id).get())
            .data()!['quantity'],
        90);
    expect((await db.collection('export_receipts').get()).docs, hasLength(1));
    expect((await db.collection('stock_movements').get()).docs, hasLength(2));
  });
}
