import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/models/stock_movement_model.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/customer_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/damage_report_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/export_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/import_receipt_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_check_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/stock_movement_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/supplier_mapper.dart';
import 'package:smart_rice_warehouse/repositories/firestore/warehouse_location_mapper.dart';

void main() {
  group('Firestore Mappers Tests', () {
    test('SupplierMapper serializes and deserializes correctly', () {
      const mapper = SupplierMapper();
      final now = DateTime.utc(2026, 10, 15, 12, 0);
      final supplier = SupplierModel(
        id: 'sup-1',
        name: 'Hợp tác xã Lúa Vàng',
        phone: '0912345678',
        email: 'luavang@gmail.com',
        address: 'An Giang',
        taxCode: '1234567890',
        isActive: true,
        note: 'Đối tác chiến lược',
        createdAt: now,
      );

      final map = mapper.toFirestore(supplier, null);
      expect(map['name'], 'Hợp tác xã Lúa Vàng');
      expect(map['email'], 'luavang@gmail.com');
      expect(map['note'], 'Đối tác chiến lược');

      final restored = mapper.fromMap('sup-1', map);
      expect(restored.id, 'sup-1');
      expect(restored.name, supplier.name);
      expect(restored.phone, supplier.phone);
      expect(restored.email, supplier.email);
    });

    test('CustomerMapper handles customerType gracefully', () {
      const mapper = CustomerMapper();
      const customer = CustomerModel(
        id: 'cust-1',
        name: 'Đại lý Gạo Miền Tây',
        phone: '0987654321',
        customerType: CustomerType.agent,
        address: 'Cần Thơ',
        isActive: true,
        email: 'mientay@gmail.com',
      );

      final map = mapper.toFirestore(customer, null);
      expect(map['customerType'], 'agent');

      final restored = mapper.fromMap('cust-1', map);
      expect(restored.customerType, CustomerType.agent);
      expect(restored.name, 'Đại lý Gạo Miền Tây');
    });

    test('BatchMapper supports snapshots and numeric decoding', () {
      const mapper = BatchMapper();
      final now = DateTime.utc(2026, 10, 1, 8, 0);
      final batch = BatchModel(
        id: 'b-01',
        code: 'LO-ST25-01',
        riceId: 'rice-st25',
        riceName: 'Gạo ST25',
        quantity: 1500.0,
        importDate: now,
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 365)),
        status: BatchStatus.available,
        supplierId: 'sup-1',
        supplierName: 'HTX Lúa Vàng',
      );

      final map = mapper.toFirestore(batch, null);
      expect(map['remainingQuantity'], 1500.0);
      expect(map['supplierNameSnapshot'], 'HTX Lúa Vàng');

      final restored = mapper.fromMap('b-01', map);
      expect(restored.code, 'LO-ST25-01');
      expect(restored.quantity, 1500.0);
      expect(restored.status, BatchStatus.available);
    });

    test('WarehouseLocationMapper serializes coordinates and capacity', () {
      const mapper = WarehouseLocationMapper();
      const loc = WarehouseLocationModel(
        id: 'loc-1',
        zone: 'Khu A',
        rack: 'Kệ 1',
        shelf: 'Tầng 1',
        code: 'A-K1-T1',
        capacity: 5000.0,
        isActive: true,
      );

      final map = mapper.toFirestore(loc, null);
      expect(map['code'], 'A-K1-T1');
      expect(map['capacity'], 5000.0);

      final restored = mapper.fromMap('loc-1', map);
      expect(restored.fullDisplayName, 'Khu A → Kệ 1 → Tầng 1 (A-K1-T1)');
    });

    test('DamageReportMapper strictly excludes local imagePath from Firestore', () {
      const mapper = DamageReportMapper();
      final now = DateTime.utc(2026, 10, 10);
      final report = DamageReportModel(
        id: 'dmg-1',
        code: 'BH-001',
        batchId: 'b-01',
        batchCode: 'LO-ST25-01',
        riceId: 'rice-st25',
        riceName: 'ST25',
        quantity: 50.0,
        reason: DamageReason.baoUot,
        createdBy: 'Admin',
        createdAt: now,
        imagePath: '/documents/smart_rice_warehouse/damage_reports/local.jpg',
      );

      final map = mapper.toFirestore(report, null);
      expect(map.containsKey('imagePath'), isFalse);

      final restored = mapper.fromMap('dmg-1', map);
      expect(restored.imagePath, isNull);
      expect(restored.quantity, 50.0);
    });

    test('ImportReceiptMapper and ExportReceiptMapper dual compatibility', () {
      const importMapper = ImportReceiptMapper();
      const exportMapper = ExportReceiptMapper();
      final now = DateTime.utc(2026, 10, 10);

      final importReceipt = ImportReceiptModel(
        id: 'imp-1',
        code: 'PN001',
        supplierId: 'sup-1',
        supplierName: 'HTX',
        date: now,
        riceId: 'rice-1',
        riceName: 'ST25',
        quantity: 1000.0,
        purchasePrice: 20000.0,
        totalAmount: 20000000.0,
        batchCode: 'LO-01',
        manufactureDate: now,
        expiryDate: now.add(const Duration(days: 180)),
      );

      final impMap = importMapper.toFirestore(importReceipt, null);
      expect(impMap['items'], isA<List>());
      expect(impMap['quantity'], 1000.0);

      final exportReceipt = ExportReceiptModel(
        id: 'exp-1',
        code: 'PX001',
        customerId: 'cust-1',
        customerName: 'Đại lý A',
        date: now,
        riceId: 'rice-1',
        riceName: 'ST25',
        quantity: 500.0,
        sellingPrice: 25000.0,
        totalAmount: 12500000.0,
        note: 'Giao sáng',
        allocations: [
          BatchAllocation(
            batchId: 'b-01',
            batchCode: 'LO-01',
            allocatedQuantity: 500.0,
            batchInitialQuantity: 1000.0,
            batchRemainingQuantity: 500.0,
            expiryDate: now.add(const Duration(days: 90)),
          ),
        ],
      );

      final expMap = exportMapper.toFirestore(exportReceipt, null);
      expect(expMap['allocations'], isA<List>());
      expect(expMap['totalAmount'], 12500000.0);

      final restoredExp = exportMapper.fromMap('exp-1', expMap);
      expect(restoredExp.allocations.length, 1);
      expect(restoredExp.allocations.first.allocatedQuantity, 500.0);
    });

    test('StockMovementMapper serializes ledger entry without mutation fields', () {
      const mapper = StockMovementMapper();
      final now = DateTime.utc(2026, 10, 15);
      final movement = StockMovementModel(
        id: 'mov-1',
        type: 'export',
        batchId: 'b-01',
        riceId: 'rice-1',
        quantityDelta: -500.0,
        quantityBefore: 1500.0,
        quantityAfter: 1000.0,
        referenceType: 'export_receipt',
        referenceId: 'exp-1',
        performedBy: 'admin',
        createdAt: now,
        note: 'Xuất kho',
      );

      final map = mapper.toFirestore(movement, null);
      expect(map['quantityDelta'], -500.0);
      expect(map['quantityAfter'], 1000.0);

      final restored = mapper.fromMap('mov-1', map);
      expect(restored.quantityDelta, -500.0);
      expect(restored.referenceType, 'export_receipt');
    });

    test('InventoryCheckMapper maps session and diff items', () {
      const mapper = InventoryCheckMapper();
      final now = DateTime.utc(2026, 10, 15);
      final session = InventoryCheckSession(
        id: 'chk-1',
        code: 'KK001',
        createdAt: now,
        createdBy: 'Admin',
        status: InventoryCheckStatus.completed,
        totalItems: 1,
        totalDifference: -20.0,
        items: const [
          InventoryCheckItem(
            batchId: 'b-01',
            batchCode: 'LO-01',
            riceName: 'ST25',
            expectedQuantity: 1000.0,
            actualQuantity: 980.0,
            difference: -20.0,
            reason: InventoryCheckReason.haoHut,
          ),
        ],
      );

      final map = mapper.toFirestore(session, null);
      expect(map['status'], 'completed');
      expect(map['totalDifference'], -20.0);

      final restored = mapper.fromMap('chk-1', map);
      expect(restored.items.first.difference, -20.0);
      expect(restored.items.first.reason, InventoryCheckReason.haoHut);
    });
  });

  group('SupplierProvider and CustomerProvider Local Tests', () {
    test('SupplierProvider search and CRUD without cloud repository', () {
      final provider = SupplierProvider(
        initial: [
          const SupplierModel(
            id: 's1',
            name: 'Lúa Miền Tây',
            phone: '0901',
            email: 'lmt@gmail.com',
            address: 'Hậu Giang',
            taxCode: '111',
            isActive: true,
          ),
        ],
      );

      expect(provider.suppliers.length, 1);
      expect(provider.searchSuppliers('Miền Tây').length, 1);
      expect(provider.searchSuppliers('Hà Nội').isEmpty, true);

      provider.addSupplier(
        const SupplierModel(
          id: 's2',
          name: 'Nông Sản Bắc',
          phone: '0902',
          email: 'nsb@gmail.com',
          address: 'Hà Nội',
          taxCode: '222',
          isActive: true,
        ),
      );

      expect(provider.suppliers.length, 2);
      expect(provider.searchSuppliers('Hà Nội').length, 1);
    });

    test('CustomerProvider search and CRUD without cloud repository', () {
      final provider = CustomerProvider(
        initial: [
          const CustomerModel(
            id: 'c1',
            name: 'Đại lý An An',
            phone: '0909',
            customerType: CustomerType.agent,
            address: 'TP.HCM',
            isActive: true,
          ),
        ],
      );

      expect(provider.customers.length, 1);
      expect(provider.searchCustomers('An An').length, 1);

      provider.updateCustomer(
        provider.customers.first.copyWith(name: 'Đại lý An Khang'),
      );
      expect(provider.findById('c1')?.name, 'Đại lý An Khang');
    });
  });
}
