import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';

void main() {
  final now = DateTime.now();

  BatchModel batch({
    required String id,
    required String code,
    double quantity = 100,
    String riceId = 'rice-a',
    String? supplierId = 'supplier-a',
  }) {
    return BatchModel(
      id: id,
      code: code,
      riceId: riceId,
      riceName: 'Gạo A',
      quantity: quantity,
      importDate: now,
      manufactureDate: now.subtract(const Duration(days: 10)),
      expiryDate: now.add(const Duration(days: 100)),
      status: BatchStatus.available,
      supplierId: supplierId,
    );
  }

  test('FEFO allocation is atomic when any allocation is invalid', () {
    final first = batch(id: 'a', code: 'A');
    final second = batch(id: 'b', code: 'B', quantity: 20);
    final provider = BatchProvider(initial: [first, second]);

    final result = provider.applyFefoAllocations([
      BatchAllocation(
        batchId: first.id,
        batchCode: first.code,
        allocatedQuantity: 10,
        batchInitialQuantity: 100,
        batchRemainingQuantity: 90,
        expiryDate: first.expiryDate,
      ),
      BatchAllocation(
        batchId: second.id,
        batchCode: second.code,
        allocatedQuantity: 30,
        batchInitialQuantity: 20,
        batchRemainingQuantity: 0,
        expiryDate: second.expiryDate,
      ),
    ]);

    expect(result, isFalse);
    expect(provider.findById('a')!.quantity, 100);
    expect(provider.findById('b')!.quantity, 20);
  });

  test('inventory check does not partially update when a batch is missing', () {
    final existing = batch(id: 'a', code: 'A');
    final missing = batch(id: 'missing', code: 'MISSING');
    final batches = BatchProvider(initial: [existing]);
    final checks = InventoryCheckProvider(initial: const []);
    checks.startNewSession();
    checks.addOrUpdateItem(
      batch: existing,
      actualQuantity: 90,
      reason: InventoryCheckReason.haoHut,
    );
    checks.addOrUpdateItem(
      batch: missing,
      actualQuantity: 80,
      reason: InventoryCheckReason.saiDuLieu,
    );

    expect(checks.completeSession(batchProvider: batches), isFalse);
    expect(batches.findById('a')!.quantity, 100);
    expect(checks.activeSession, isNotNull);
  });

  test('duplicate batch import rejects incompatible lot metadata', () {
    final existing = batch(id: 'a', code: 'LOT-01');
    final batches = BatchProvider(initial: [existing]);
    final imports = ImportProvider(batches, initial: const []);
    final incompatible = batch(
      id: 'b',
      code: 'LOT-01',
      riceId: 'rice-b',
    );
    final receipt = ImportReceiptModel(
      id: 'receipt-1',
      code: 'PN001',
      supplierId: 'supplier-a',
      supplierName: 'Supplier A',
      date: now,
      riceId: 'rice-b',
      riceName: 'Gạo B',
      quantity: 100,
      purchasePrice: 10000,
      totalAmount: 1000000,
      batchCode: 'LOT-01',
      manufactureDate: incompatible.manufactureDate,
      expiryDate: incompatible.expiryDate,
    );

    expect(
      imports.createImportReceipt(receipt: receipt, batch: incompatible),
      isFalse,
    );
    expect(batches.findById('a')!.quantity, 100);
    expect(imports.receipts, isEmpty);
  });

  test('warehouse assignment enforces active state and weight capacity', () {
    final target = batch(id: 'a', code: 'A', quantity: 120);
    final batches = BatchProvider(initial: [target]);
    final warehouse = WarehouseProvider(
      initial: const [
        WarehouseLocationModel(
          id: 'small',
          zone: 'A',
          rack: '1',
          shelf: '1',
          code: 'A-1-1',
          capacity: 100,
        ),
        WarehouseLocationModel(
          id: 'large',
          zone: 'A',
          rack: '1',
          shelf: '2',
          code: 'A-1-2',
          capacity: 200,
        ),
      ],
    );

    expect(
      warehouse.assignBatch(
        batchProvider: batches,
        batchId: 'a',
        locationId: 'small',
      ),
      isFalse,
    );
    expect(batches.findById('a')!.warehouseLocationId, isNull);
    expect(
      warehouse.assignBatch(
        batchProvider: batches,
        batchId: 'a',
        locationId: 'large',
      ),
      isTrue,
    );
    expect(batches.findById('a')!.warehouseLocationId, 'large');
    expect(warehouse.findById('large')!.currentBatchCount, 1);
  });

  test('auth hashes passwords, persists remember state and supports change',
      () {
    String? savedHash;
    bool? remembered;
    final auth = AuthProvider(
      onPersist: (_, hash, remember) {
        savedHash = hash;
        remembered = remember;
      },
    );

    expect(
      auth.login(
        email: 'admin@gmail.com',
        password: '123456',
        remember: true,
      ),
      isTrue,
    );
    expect(savedHash, isNot('123456'));
    expect(remembered, isTrue);
    expect(
      auth.changePassword(current: '123456', replacement: 'new-password'),
      isTrue,
    );
    auth.logout();
    expect(
      auth.login(email: 'admin@gmail.com', password: 'new-password'),
      isTrue,
    );
  });
}
