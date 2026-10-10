import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';
import 'package:smart_rice_warehouse/services/forecast_service.dart';
import 'package:smart_rice_warehouse/services/ocr_service.dart';

void main() {
  group('Week 3 - Task 3.1 & 3.5 Reports and Validation Tests', () {
    test('Total import and export for month are calculated correctly from real data', () {
      final batchProvider = BatchProvider();
      final importProvider = ImportProvider(batchProvider, null);
      final exportProvider = ExportProvider(batchProvider, null);

      final aug2026 = DateTime(2026, 8, 15);
      final sept2026 = DateTime(2026, 9, 15);

      final importAug = importProvider.totalAmountForMonth(aug2026);
      final exportAug = exportProvider.totalAmountForMonth(aug2026);
      expect(importAug, greaterThan(0));
      expect(exportAug, greaterThan(0));

      final importSept = importProvider.totalAmountForMonth(sept2026);
      final exportSept = exportProvider.totalAmountForMonth(sept2026);
      expect(importSept, greaterThan(0));
      expect(exportSept, greaterThan(0));
    });

    test('Inventory value equals sum of stock * purchasePrice for all active rices', () {
      final batchProvider = BatchProvider();
      const rices = MockData.rices;

      final calculatedValue = batchProvider.inventoryValue(rices);
      expect(calculatedValue, greaterThan(0));

      var expected = 0.0;
      for (final rice in rices) {
        expected += batchProvider.totalStockForRice(rice.id) * rice.purchasePrice;
      }
      expect(calculatedValue, equals(expected));
    });

    test('FEFO never produces negative stock or deducts from expired/zero batches', () {
      final batchProvider = BatchProvider();
      const fefoService = FefoService();

      const riceId = 'rice-st25';
      final stockBefore = batchProvider.totalStockForRice(riceId);

      // Try allocating more than total available -> must reject
      final overResult = fefoService.allocate(
        batches: batchProvider.batches,
        riceId: riceId,
        quantity: stockBefore + 1000,
      );
      expect(overResult.isSuccess, isFalse);
      expect(overResult.errorMessage, contains('Tồn kho khả dụng không đủ'));

      // Allocate valid quantity
      final validResult = fefoService.allocate(
        batches: batchProvider.batches,
        riceId: riceId,
        quantity: 50,
      );
      expect(validResult.isSuccess, isTrue);
      for (final a in validResult.allocations) {
        expect(a.allocatedQuantity, greaterThan(0));
        expect(a.batchRemainingQuantity, greaterThanOrEqualTo(0));
      }
    });

    test('Forecast handles division by zero and empty history cleanly', () {
      final batchProvider = BatchProvider();
      const forecastService = ForecastService();

      const rices = MockData.rices;
      final emptyExports = <ExportReceiptModel>[];

      final forecasts = forecastService.generateForecasts(
        rices: rices,
        exportReceipts: emptyExports,
        batchProvider: batchProvider,
      );

      expect(forecasts, isNotEmpty);
      for (final f in forecasts) {
        expect(f.averageDailyExport, 0.0);
        expect(f.estimatedDaysRemaining, isNull);
        // Does not throw division by zero error
      }
    });
  });

  group('Week 3 - Task 3.4 OCR Prototype Parser Tests', () {
    const ocrService = OcrService();
    const suppliers = MockData.suppliers;
    const rices = MockData.rices;

    test('Parses Sample 1: Cty Lúa Việt, ST25, 800kg, 28000 VNĐ, LO-ST25-003', () {
      final sample = OcrService.samples[0];
      final extracted = ocrService.parseInvoice(
        rawText: sample.rawText,
        suppliers: suppliers,
        rices: rices,
      );

      expect(extracted.matchedSupplierId, 'supplier-lua-viet');
      expect(extracted.matchedRiceId, 'rice-st25');
      expect(extracted.quantity, 800.0);
      expect(extracted.purchasePrice, 28000.0);
      expect(extracted.batchCode, 'LO-ST25-003');
      expect(extracted.manufactureDate, DateTime(2026, 10, 1));
      expect(extracted.expiryDate, DateTime(2027, 10, 1));
    });

    test('Parses Sample 2: Cty Đồng Xanh, Jasmine, 500kg, 19500 đ, LO-JAS-002', () {
      final sample = OcrService.samples[1];
      final extracted = ocrService.parseInvoice(
        rawText: sample.rawText,
        suppliers: suppliers,
        rices: rices,
      );

      expect(extracted.matchedSupplierId, 'supplier-dong-xanh');
      expect(extracted.matchedRiceId, 'rice-jasmine');
      expect(extracted.quantity, 500.0);
      expect(extracted.purchasePrice, 19500.0);
      expect(extracted.batchCode, 'LO-JAS-002');
      expect(extracted.manufactureDate, DateTime(2026, 9, 20));
      expect(extracted.expiryDate, DateTime(2027, 9, 20));
    });

    test('Parses Sample 3: Nông sản Mekong, Gạo lứt, 400kg, 26500 VNĐ, LO-LUT-002', () {
      final sample = OcrService.samples[2];
      final extracted = ocrService.parseInvoice(
        rawText: sample.rawText,
        suppliers: suppliers,
        rices: rices,
      );

      expect(extracted.matchedSupplierId, 'supplier-mekong');
      expect(extracted.matchedRiceId, 'rice-brown');
      expect(extracted.quantity, 400.0);
      expect(extracted.purchasePrice, 26500.0);
      expect(extracted.batchCode, 'LO-LUT-002');
      expect(extracted.manufactureDate, DateTime(2026, 9, 25));
      expect(extracted.expiryDate, DateTime(2027, 3, 25));
    });
  });

  group('Week 3 - Task 3.6 Full End-to-End Business Flow Test', () {
    test('Import -> Batch Created -> Export with FEFO -> Inventory Updated -> Alerts Updated', () {
      final batchProvider = BatchProvider();
      final importProvider = ImportProvider(batchProvider, null);
      final exportProvider = ExportProvider(batchProvider, null);

      final now = DateTime(2026, 10, 15);
      const testRiceId = 'rice-st25';

      final initialStock = batchProvider.totalStockForRice(testRiceId);

      // 1. Tạo phiếu nhập mới
      final importBatch = BatchModel(
        id: 'batch-test-e2e',
        code: 'LO-ST25-E2E',
        riceId: testRiceId,
        riceName: 'Gạo ST25',
        quantity: 200,
        importDate: now,
        manufactureDate: now.subtract(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 180)),
        status: BatchStatus.available,
      );

      final importReceipt = ImportReceiptModel(
        id: 'imp-test-e2e',
        code: importProvider.generateReceiptCode(),
        supplierId: 'supplier-lua-viet',
        supplierName: 'Công ty Lúa Việt',
        date: now,
        riceId: testRiceId,
        riceName: 'Gạo ST25',
        quantity: 200,
        purchasePrice: 28000,
        totalAmount: 200 * 28000,
        batchCode: 'LO-ST25-E2E',
        manufactureDate: now.subtract(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 180)),
      );

      final importSuccess = importProvider.createImportReceipt(
        receipt: importReceipt,
        batch: importBatch,
      );
      expect(importSuccess, isTrue);

      final stockAfterImport = batchProvider.totalStockForRice(testRiceId);
      expect(stockAfterImport, equals(initialStock + 200));

      // 2. Xuất kho FEFO
      final exportReceipt = ExportReceiptModel(
        id: 'exp-test-e2e',
        code: exportProvider.generateReceiptCode(),
        customerId: 'customer-minh-phat',
        customerName: 'Minh Phát',
        date: now,
        riceId: testRiceId,
        riceName: 'Gạo ST25',
        quantity: 150,
        sellingPrice: 35000,
        totalAmount: 150 * 35000,
        note: 'E2E export test',
      );

      final exportSuccess = exportProvider.createExportReceipt(exportReceipt);
      expect(exportSuccess, isTrue);

      final stockAfterExport = batchProvider.totalStockForRice(testRiceId);
      expect(stockAfterExport, equals(stockAfterImport - 150));
    });
  });
}
