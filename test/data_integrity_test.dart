import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_rice_warehouse/data/local/settings_service.dart';
import 'package:smart_rice_warehouse/logic/services/excel_export_service.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_snapshot_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/presentation/theme/theme_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';

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

  test('inventory check does not partially update when a batch is missing',
      () async {
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

    expect(await checks.completeSession(batchProvider: batches), isFalse);
    expect(batches.findById('a')!.quantity, 100);
    expect(checks.activeSession, isNotNull);
  });

  test('duplicate batch import rejects incompatible lot metadata', () async {
    final existing = batch(id: 'a', code: 'LOT-01');
    final batches = BatchProvider(initial: [existing]);
    final imports = ImportProvider(batches, initial: const []);
    final incompatible = batch(
      code: 'LOT-01',
      id: 'b',
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
      await imports.createImportReceipt(receipt: receipt, batch: incompatible),
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
      demoMode: true,
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

  test('catalog deletes persist the resulting collections', () {
    var ricePersisted = false;
    var supplierPersisted = false;
    var customerPersisted = false;
    final riceProvider = RiceProvider(
      initial: [MockData.rices.first],
      onPersist: (items) => ricePersisted = items.isEmpty,
    );
    final supplierProvider = SupplierProvider(
      initial: [MockData.suppliers.first],
      onPersist: (items) => supplierPersisted = items.isEmpty,
    );
    final customerProvider = CustomerProvider(
      initial: [MockData.customers.first],
      onPersist: (items) => customerPersisted = items.isEmpty,
    );

    expect(riceProvider.deleteRice(MockData.rices.first.id), isTrue);
    expect(
      supplierProvider.deleteSupplier(MockData.suppliers.first.id),
      isTrue,
    );
    expect(
      customerProvider.deleteCustomer(MockData.customers.first.id),
      isTrue,
    );
    expect(ricePersisted, isTrue);
    expect(supplierPersisted, isTrue);
    expect(customerPersisted, isTrue);
  });

  test('inventory quantity adjustments are persisted', () {
    List<BatchModel>? persisted;
    final provider = BatchProvider(
      initial: [batch(id: 'a', code: 'A')],
      onPersist: (items) => persisted = items,
    );

    expect(provider.adjustQuantities({'a': 42}), isTrue);
    expect(provider.findById('a')!.quantity, 42);
    expect(persisted, isNotNull);
    expect(persisted!.single.quantity, 42);
  });

  test('profile updates are validated, notified and persisted', () {
    String? savedName;
    String? savedRole;
    String? savedAvatar;
    final auth = AuthProvider(
      demoMode: true,
      rememberedSession: true,
      onProfilePersist: (name, role, avatar) {
        savedName = name;
        savedRole = role;
        savedAvatar = avatar;
      },
    );

    expect(
      auth.updateProfile(
        name: 'Quản lý Kho A',
        role: 'Quản lý vận hành',
        avatarPath: 'avatar/profile.jpg',
      ),
      isTrue,
    );
    expect(auth.currentUser!.name, 'Quản lý Kho A');
    expect(auth.currentUser!.role, 'Quản lý vận hành');
    expect(auth.currentUser!.avatarPath, 'avatar/profile.jpg');
    expect(savedName, 'Quản lý Kho A');
    expect(savedRole, 'Quản lý vận hành');
    expect(savedAvatar, 'avatar/profile.jpg');
  });

  test('theme and operational settings survive service recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.init();
    final theme = ThemeProvider(
      initialDarkMode: settings.isDarkMode,
      onChanged: settings.setDarkMode,
    );

    theme.toggleTheme(true);
    await settings.setPushNotifications(false);
    await settings.setBackgroundSync(false);
    await Future<void>.delayed(Duration.zero);

    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.isDarkMode, isTrue);
    expect(reloaded.pushNotifications, isFalse);
    expect(reloaded.backgroundSync, isFalse);
  });

  test('inventory snapshots upsert one accurate value per day', () {
    var persistCount = 0;
    final rice = MockData.rices.first;
    final store = InventorySnapshotStore(
      onPersist: (_) => persistCount++,
    );
    final firstBatch = batch(
      id: 'snapshot-a',
      code: 'SNAP-A',
      quantity: 10,
      riceId: rice.id,
    );
    final date = DateTime(2026, 10, 11, 8);

    store.synchronize(
      batches: [firstBatch],
      rices: [rice],
      recordedAt: date,
    );
    store.synchronize(
      batches: [firstBatch.copyWith(quantity: 6)],
      rices: [rice],
      recordedAt: date.add(const Duration(hours: 2)),
    );

    expect(store.snapshots, hasLength(1));
    expect(store.snapshots.single.totalQuantity, 6);
    expect(store.snapshots.single.totalValue, 6 * rice.purchasePrice);
    expect(persistCount, 2);
  });

  test('inventory Excel report is generated as a real XLSX archive', () {
    final rice = MockData.rices.first;
    final bytes = ExcelExportService.buildInventoryReport(
      [
        batch(
          id: 'excel-a',
          code: 'EXCEL-A',
          quantity: 25,
          riceId: rice.id,
        ),
      ],
      [rice],
    );

    expect(bytes.length, greaterThan(100));
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });
}
