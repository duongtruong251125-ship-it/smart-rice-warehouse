import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/services/catalog_form_service.dart';
import 'package:smart_rice_warehouse/logic/view_models/batch_list_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/damage_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/inventory_check_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/inventory_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/warehouse_hub_view_model.dart';

void main() {
  final fixedDate = DateTime(2026, 10, 19, 10, 0);

  group('BatchListViewModel', () {
    test('filters batches by query and filter option correctly', () {
      final vm = BatchListViewModel();
      addTearDown(vm.dispose);

      final b1 = BatchModel(
        id: 'b1',
        code: 'LO-ST25-001',
        riceId: 'rice-1',
        riceName: 'ST25',
        quantity: 1000,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 10)),
        status: BatchStatus.available,
      );
      final b2 = BatchModel(
        id: 'b2',
        code: 'LO-JAS-002',
        riceId: 'rice-2',
        riceName: 'Jasmine',
        quantity: 0,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 300)),
        status: BatchStatus.available,
      );

      final batches = [b1, b2];

      // Query filter
      vm.setQuery('ST25');
      final result1 = vm.filterBatches(batches);
      expect(result1.length, 1);
      expect(result1.first.code, 'LO-ST25-001');

      // Filter by "Còn hàng"
      vm.setQuery('');
      vm.setFilter('Còn hàng');
      final result2 = vm.filterBatches(batches);
      expect(result2.length, 1);
      expect(result2.first.code, 'LO-ST25-001');

      // Filter by "Cần ưu tiên xuất"
      vm.setFilter('Cần ưu tiên xuất');
      final result3 = vm.filterBatches(batches);
      expect(result3.length, 1);
      expect(result3.first.code, 'LO-ST25-001');

      // Metrics calculation
      final metrics = vm.calculateMetrics(batches);
      expect(metrics.totalKg, 1000);
      expect(metrics.totalTons, 1.0);
      expect(metrics.totalBags, 20);
    });
  });

  group('InventoryViewModel', () {
    test('filters rices and calculates inventory metrics', () {
      final vm = InventoryViewModel();
      addTearDown(vm.dispose);

      final futureExpiry = DateTime.now().add(const Duration(days: 365));

      final rice1 = MockData.rices.first.copyWith(
        id: 'r1',
        code: 'ST25',
        name: 'Gạo ST25',
        minimumStock: 500,
      );
      final rice2 =
          (MockData.rices.length > 1 ? MockData.rices[1] : MockData.rices.first)
              .copyWith(
        id: 'r2',
        code: 'JAS',
        name: 'Gạo Jasmine',
        minimumStock: 500,
      );

      final batchProvider = BatchProvider(initial: [
        BatchModel(
          id: 'b1',
          code: 'LO-1',
          riceId: 'r1',
          riceName: 'Gạo ST25',
          quantity: 100,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: futureExpiry,
          status: BatchStatus.available,
        ),
        BatchModel(
          id: 'b2',
          code: 'LO-2',
          riceId: 'r2',
          riceName: 'Gạo Jasmine',
          quantity: 2000,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: futureExpiry,
          status: BatchStatus.available,
        ),
      ]);

      final allRices = <RiceModel>[rice1, rice2];

      // Test "Cần nhập thêm"
      vm.setFilter('Cần nhập thêm');
      final lowStockList = vm.filterRices(
        allRices: allRices,
        batchProvider: batchProvider,
      );
      expect(lowStockList.length, 1);
      expect(lowStockList.first.id, 'r1');

      // Test "Đủ hàng"
      vm.setFilter('Đủ hàng');
      final highStockList = vm.filterRices(
        allRices: allRices,
        batchProvider: batchProvider,
      );
      expect(highStockList.length, 1);
      expect(highStockList.first.id, 'r2');

      // Test calculateMetrics
      final metrics = vm.calculateMetrics(
        rices: allRices,
        batchProvider: batchProvider,
      );
      expect(metrics.totalKg, 2100);
      expect(metrics.totalBags, 42);
    });
  });

  group('WarehouseHubViewModel', () {
    test('computes warehouse hub summary metrics accurately', () {
      final batchProvider = BatchProvider(initial: [
        BatchModel(
          id: 'b1',
          code: 'LO-1',
          riceId: 'r1',
          riceName: 'ST25',
          quantity: 25000,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: fixedDate.add(const Duration(days: 100)),
          status: BatchStatus.available,
        ),
      ]);
      final warehouseProvider = WarehouseProvider(initial: [
        const WarehouseLocationModel(
          id: 'loc1',
          zone: 'Khu A',
          rack: 'Kệ 1',
          shelf: 'Tầng 1',
          code: 'SILO-01',
          capacity: 50000,
        ),
      ]);
      final riceProvider = RiceProvider(initial: [MockData.rices.first]);
      final supplierProvider =
          SupplierProvider(initial: [MockData.suppliers.first]);
      final customerProvider =
          CustomerProvider(initial: [MockData.customers.first]);
      final damageProvider = DamageProvider(initial: []);

      final vm = WarehouseHubViewModel(
        warehouseProvider: warehouseProvider,
        batchProvider: batchProvider,
        riceProvider: riceProvider,
        supplierProvider: supplierProvider,
        customerProvider: customerProvider,
        damageProvider: damageProvider,
        maxCapacityTons: 100.0,
      );

      expect(vm.totalKg, 25000);
      expect(vm.totalTons, 25.0);
      expect(vm.totalBags, 500);
      expect(vm.capacityPercent, 0.25);
      expect(vm.locationCount, 1);
      expect(vm.batchCount, 1);
      expect(vm.riceCount, 1);
      expect(vm.supplierCount, 1);
      expect(vm.customerCount, 1);
      expect(vm.damageReportCount, 0);
    });
  });

  group('InventoryCheckViewModel', () {
    test('starts session, updates item check, and completes session', () async {
      final vm = InventoryCheckViewModel();
      addTearDown(vm.dispose);

      final checkProvider = InventoryCheckProvider(initial: []);
      final batchProvider = BatchProvider(initial: [
        BatchModel(
          id: 'b1',
          code: 'LO-1',
          riceId: 'r1',
          riceName: 'ST25',
          quantity: 1000,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: fixedDate.add(const Duration(days: 100)),
          status: BatchStatus.available,
        ),
      ]);

      vm.ensureActiveSession(checkProvider: checkProvider);
      expect(checkProvider.hasActiveSession, isTrue);

      final batch = batchProvider.findById('b1')!;
      final saveResult = vm.saveItemCount(
        checkProvider: checkProvider,
        batch: batch,
        actualQuantityText: '950',
        reason: InventoryCheckReason.haoHut,
        note: 'Hao hụt tự nhiên',
      );

      expect(saveResult.success, isTrue);
      expect(saveResult.difference, -50.0);

      final completeResult = await vm.completeSession(
        checkProvider: checkProvider,
        batchProvider: batchProvider,
      );

      expect(completeResult.success, isTrue);
      expect(completeResult.itemCount, 1);
      expect(completeResult.totalDifference, -50.0);
      expect(batchProvider.findById('b1')!.quantity, 950);
      expect(checkProvider.hasActiveSession, isFalse);
    });
  });

  group('DamageFormViewModel', () {
    test('validates and submits damage report adjusting batch quantity',
        () async {
      final batch = BatchModel(
        id: 'b-dmg',
        code: 'LO-DMG',
        riceId: 'r1',
        riceName: 'ST25',
        quantity: 500,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 100)),
        status: BatchStatus.available,
      );

      final batchProvider = BatchProvider(initial: [batch]);
      final damageProvider = DamageProvider(initial: []);

      final vm = DamageFormViewModel(initialBatch: batch);
      addTearDown(vm.dispose);

      vm.setSelectedReason(DamageReason.conTrung);
      final result = await vm.submit(
        batchProvider: batchProvider,
        damageProvider: damageProvider,
        quantityText: '50',
        note: 'Bị mọt phá hoại',
        createdBy: 'Kiểm kho',
      );

      expect(result.success, isTrue);
      expect(result.quantity, 50.0);
      expect(batchProvider.findById('b-dmg')!.quantity, 450);
      expect(damageProvider.reports.length, 1);
      expect(damageProvider.reports.first.quantity, 50);
    });
  });

  group('CatalogFormService multi-provider orchestration', () {
    test('deleteRice blocks deletion when referenced in batches', () async {
      final service = CatalogFormService();
      final rice = MockData.rices.first;
      final riceProvider = RiceProvider(initial: [rice]);
      final batchProvider = BatchProvider(initial: [
        BatchModel(
          id: 'b-ref',
          code: 'LO-REF',
          riceId: rice.id,
          riceName: rice.name,
          quantity: 100,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: fixedDate.add(const Duration(days: 100)),
          status: BatchStatus.available,
        ),
      ]);

      final result = await service.deleteRice(
        riceProvider: riceProvider,
        batchProvider: batchProvider,
        rice: rice,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('đang được sử dụng trong lô hàng'));
      expect(riceProvider.rices.any((r) => r.id == rice.id), isTrue);
    });

    test('deleteSupplier blocks deletion when referenced in batches', () async {
      final service = CatalogFormService();
      final supplier = MockData.suppliers.first;
      final supplierProvider = SupplierProvider(initial: [supplier]);
      final batchProvider = BatchProvider(initial: [
        BatchModel(
          id: 'b-sup',
          code: 'LO-SUP',
          riceId: 'rice-1',
          riceName: 'ST25',
          supplierId: supplier.id,
          quantity: 100,
          importDate: fixedDate,
          manufactureDate: fixedDate,
          expiryDate: fixedDate.add(const Duration(days: 100)),
          status: BatchStatus.available,
        ),
      ]);

      final result = await service.deleteSupplier(
        supplierProvider: supplierProvider,
        batchProvider: batchProvider,
        supplier: supplier,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('đang có lô hàng liên quan'));
      expect(
          supplierProvider.suppliers.any((s) => s.id == supplier.id), isTrue);
    });

    test('deleteCustomer blocks deletion when referenced in export receipts',
        () async {
      final service = CatalogFormService();
      final customer = MockData.customers.first;
      final customerProvider = CustomerProvider(initial: [customer]);
      final batchProvider = BatchProvider(initial: []);
      final exportProvider = ExportProvider(
        batchProvider,
        initial: [
          ExportReceiptModel(
            id: 'exp-1',
            code: 'XK-001',
            date: fixedDate,
            customerId: customer.id,
            customerName: customer.name,
            riceId: 'rice-1',
            riceName: 'ST25',
            quantity: 100,
            sellingPrice: 20000,
            totalAmount: 2000000,
            note: '',
          ),
        ],
      );

      final result = await service.deleteCustomer(
        customerProvider: customerProvider,
        exportProvider: exportProvider,
        customer: customer,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('đã có phiếu xuất liên quan'));
      expect(
          customerProvider.customers.any((c) => c.id == customer.id), isTrue);
    });

    test('assignBatchLocation moves batch to new warehouse location', () async {
      final service = CatalogFormService();
      final batch = BatchModel(
        id: 'b-loc',
        code: 'LO-LOC',
        riceId: 'r1',
        riceName: 'ST25',
        quantity: 500,
        warehouseLocationId: 'loc-old',
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 100)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      final warehouseProvider = WarehouseProvider(initial: [
        const WarehouseLocationModel(
          id: 'loc-new',
          zone: 'Khu A',
          rack: 'Kệ 2',
          shelf: 'Tầng 1',
          code: 'SILO-02',
          capacity: 5000,
        ),
      ]);

      final result = await service.assignBatchLocation(
        warehouseProvider: warehouseProvider,
        batchProvider: batchProvider,
        batch: batch,
        locationId: 'loc-new',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Đã chuyển lô LO-LOC đến SILO-02'));
      expect(batchProvider.findById('b-loc')!.warehouseLocationId, 'loc-new');
    });
  });
}
