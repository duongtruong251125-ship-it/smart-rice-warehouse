import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';

void main() {
  group('FEFO Service Engine Tests', () {
    const service = FefoService();
    final today = DateTime(2026, 10, 1);

    BatchModel makeBatch({
      required String id,
      required String code,
      required String riceId,
      required double quantity,
      required DateTime expiryDate,
      BatchStatus status = BatchStatus.available,
    }) {
      return BatchModel(
        id: id,
        code: code,
        riceId: riceId,
        riceName: 'Gạo Test',
        quantity: quantity,
        importDate: DateTime(2026, 9, 1),
        manufactureDate: DateTime(2026, 8, 1),
        expiryDate: expiryDate,
        status: status,
      );
    }

    test('1. 1 batch đủ hàng: phân bổ chính xác từ lô gần hết hạn', () {
      final batches = [
        makeBatch(
          id: 'b1',
          code: 'LOT-01',
          riceId: 'rice-1',
          quantity: 100,
          expiryDate: DateTime(2026, 11, 1),
        ),
        makeBatch(
          id: 'b2',
          code: 'LOT-02',
          riceId: 'rice-1',
          quantity: 100,
          expiryDate: DateTime(2026, 12, 1),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 50,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 1);
      expect(result.allocations.first.batchCode, 'LOT-01');
      expect(result.allocations.first.allocatedQuantity, 50);
      expect(result.allocations.first.batchRemainingQuantity, 50);
    });

    test('2. 2 batch mới đủ: phân bổ hết batch 1 và một phần batch 2', () {
      final batches = [
        makeBatch(
          id: 'b1',
          code: 'LOT-01',
          riceId: 'rice-1',
          quantity: 30,
          expiryDate: DateTime(2026, 10, 15),
        ),
        makeBatch(
          id: 'b2',
          code: 'LOT-02',
          riceId: 'rice-1',
          quantity: 50,
          expiryDate: DateTime(2026, 11, 1),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 50,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 2);
      expect(result.allocations[0].batchCode, 'LOT-01');
      expect(result.allocations[0].allocatedQuantity, 30);
      expect(result.allocations[0].batchRemainingQuantity, 0);

      expect(result.allocations[1].batchCode, 'LOT-02');
      expect(result.allocations[1].allocatedQuantity, 20);
      expect(result.allocations[1].batchRemainingQuantity, 30);
    });

    test('3. 3 batch mới đủ: phân bổ hết batch 1, batch 2 và một phần batch 3', () {
      final batches = [
        makeBatch(
          id: 'b1',
          code: 'LOT-01',
          riceId: 'rice-1',
          quantity: 20,
          expiryDate: DateTime(2026, 10, 10),
        ),
        makeBatch(
          id: 'b2',
          code: 'LOT-02',
          riceId: 'rice-1',
          quantity: 40,
          expiryDate: DateTime(2026, 11, 10),
        ),
        makeBatch(
          id: 'b3',
          code: 'LOT-03',
          riceId: 'rice-1',
          quantity: 50,
          expiryDate: DateTime(2026, 12, 10),
        ),
      ];

      // Need 70 as in work plan example: LOT01=20, LOT02=40, LOT03=10
      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 70,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 3);
      expect(result.allocations[0].batchCode, 'LOT-01');
      expect(result.allocations[0].allocatedQuantity, 20);
      expect(result.allocations[1].batchCode, 'LOT-02');
      expect(result.allocations[1].allocatedQuantity, 40);
      expect(result.allocations[2].batchCode, 'LOT-03');
      expect(result.allocations[2].allocatedQuantity, 10);
      expect(result.allocations[2].batchRemainingQuantity, 40);
    });

    test('4. requested = total available: phân bổ vét sạch các lô khả dụng', () {
      final batches = [
        makeBatch(
          id: 'b1',
          code: 'LOT-01',
          riceId: 'rice-1',
          quantity: 25,
          expiryDate: DateTime(2026, 11, 1),
        ),
        makeBatch(
          id: 'b2',
          code: 'LOT-02',
          riceId: 'rice-1',
          quantity: 75,
          expiryDate: DateTime(2026, 12, 1),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 100,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocatedQuantity, 100);
      expect(result.allocations.fold(0.0, (s, a) => s + a.batchRemainingQuantity), 0);
    });

    test('5. requested > available -> reject với thông báo lỗi', () {
      final batches = [
        makeBatch(
          id: 'b1',
          code: 'LOT-01',
          riceId: 'rice-1',
          quantity: 20,
          expiryDate: DateTime(2026, 11, 1),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 50,
        currentDate: today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Tồn kho khả dụng không đủ'));
    });

    test('6. Batch gần hạn nhưng expired -> skip, chỉ lấy batch còn hạn', () {
      final batches = [
        makeBatch(
          id: 'b-exp',
          code: 'LOT-EXPIRED',
          riceId: 'rice-1',
          quantity: 100,
          expiryDate: DateTime(2026, 9, 20), // Quá hạn so với today (2026-10-01)
        ),
        makeBatch(
          id: 'b-valid',
          code: 'LOT-VALID',
          riceId: 'rice-1',
          quantity: 60,
          expiryDate: DateTime(2026, 10, 15),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 50,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 1);
      expect(result.allocations.first.batchCode, 'LOT-VALID');
    });

    test('7. Batch quantity = 0 -> skip', () {
      final batches = [
        makeBatch(
          id: 'b-zero',
          code: 'LOT-ZERO',
          riceId: 'rice-1',
          quantity: 0,
          expiryDate: DateTime(2026, 10, 5),
        ),
        makeBatch(
          id: 'b-active',
          code: 'LOT-ACTIVE',
          riceId: 'rice-1',
          quantity: 80,
          expiryDate: DateTime(2026, 10, 20),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 30,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 1);
      expect(result.allocations.first.batchCode, 'LOT-ACTIVE');
    });

    test('8. Không có batch hợp lệ -> reject', () {
      final batches = [
        makeBatch(
          id: 'b-exp',
          code: 'LOT-EXPIRED',
          riceId: 'rice-1',
          quantity: 50,
          expiryDate: DateTime(2026, 8, 1),
        ),
      ];

      final result = service.allocate(
        batches: batches,
        riceId: 'rice-1',
        quantity: 10,
        currentDate: today,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Không có lô hàng hợp lệ'));
    });

    test('9. Export xong -> total inventory bằng tổng quantity batch còn lại', () {
      final batchProvider = BatchProvider();
      final exportProvider = ExportProvider(batchProvider, null);

      const riceId = 'rice-st25';
      final initialStock = batchProvider.totalStockForRice(riceId);
      expect(initialStock, greaterThan(0));

      const exportQty = 100.0;
      final receipt = ExportReceiptModel(
        id: 'test-exp-01',
        code: 'PX-TEST-01',
        customerId: 'customer-minh-phat',
        customerName: 'Minh Phat',
        date: DateTime.now(),
        riceId: riceId,
        riceName: 'Gạo ST25',
        quantity: exportQty,
        sellingPrice: 35000,
        totalAmount: exportQty * 35000,
        note: 'Test FEFO export flow',
      );

      final success = exportProvider.createExportReceipt(receipt);
      expect(success, isTrue);

      final finalStock = batchProvider.totalStockForRice(riceId);
      expect(finalStock, closeTo(initialStock - exportQty, 0.001));

      // Check that receipt stored the allocations
      final savedReceipt = exportProvider.receipts.firstWhere((r) => r.id == 'test-exp-01');
      expect(savedReceipt.allocations, isNotEmpty);
      expect(savedReceipt.allocations.fold(0.0, (s, a) => s + a.allocatedQuantity), exportQty);
    });
  });
}
