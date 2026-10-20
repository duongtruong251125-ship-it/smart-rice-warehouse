import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/export_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/import_form_view_model.dart';
import 'package:smart_rice_warehouse/logic/view_models/ocr_invoice_view_model.dart';

void main() {
  final rice1 = MockData.rices.first;
  final rice2 =
      MockData.rices.length > 1 ? MockData.rices[1] : MockData.rices.first;
  final supplier = MockData.suppliers.first;
  final customer = MockData.customers.first;
  final fixedDate = DateTime(2026, 10, 19, 10, 0);

  group('ImportFormViewModel', () {
    test('auto-selects first batch if rice has existing batches', () {
      final batch = BatchModel(
        id: 'b-1',
        code: 'LO-ST25-001',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 500,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 180)),
        status: BatchStatus.available,
      );
      final vm = ImportFormViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.setRice(rice1, [batch]);

      expect(vm.selectedRice, rice1);
      expect(vm.selectedBatchCode, 'LO-ST25-001');
      expect(vm.isCreatingNewBatch, isFalse);
      expect(vm.manufactureDate, batch.manufactureDate);
      expect(vm.expiryDate, batch.expiryDate);
    });

    test('auto-selects new batch mode if rice has no existing batches', () {
      final vm = ImportFormViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.setRice(rice2, []);

      expect(vm.selectedRice, rice2);
      expect(vm.selectedBatchCode, ImportFormViewModel.newBatchOption);
      expect(vm.isCreatingNewBatch, isTrue);
      expect(vm.suggestedBatchCode, 'LO-${rice2.code}-001');
      expect(vm.manufactureDate, fixedDate);
      expect(vm.expiryDate, fixedDate.add(const Duration(days: 365)));
    });

    test(
        'suggests incremented batch code when creating new batch for existing rice',
        () {
      final batch1 = BatchModel(
        id: 'b-1',
        code: 'LO-${rice1.code}-001',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 100,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 100)),
        status: BatchStatus.available,
      );
      final batch2 = BatchModel(
        id: 'b-2',
        code: 'LO-${rice1.code}-002',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 200,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 100)),
        status: BatchStatus.available,
      );

      final vm = ImportFormViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.setRice(rice1, [batch1, batch2]);
      vm.selectNewBatchMode(rice: rice1, allBatches: [batch1, batch2]);

      expect(vm.isCreatingNewBatch, isTrue);
      expect(vm.suggestedBatchCode, 'LO-${rice1.code}-003');
    });

    test('validates duplicate batch code against BatchProvider', () {
      final batch = BatchModel(
        id: 'b-1',
        code: 'LO-EXISTING-01',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 100,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 100)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      addTearDown(batchProvider.dispose);

      final vm = ImportFormViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.selectNewBatchMode(allBatches: [batch]);
      expect(vm.validateBatchCode('LO-EXISTING-01', batchProvider),
          contains('đã tồn tại'));
      expect(vm.validateBatchCode('LO-BRAND-NEW', batchProvider), isNull);
      expect(vm.validateBatchCode('', batchProvider),
          contains('Vui lòng nhập mã lô mới'));
    });

    test('calculates total amount correctly', () {
      final vm = ImportFormViewModel();
      addTearDown(vm.dispose);

      expect(vm.calculateTotalAmount('10', '15000'), 150000);
      expect(vm.calculateTotalAmount('abc', '15000'), 0);
      expect(vm.calculateTotalAmount('-5', '15000'), 0);
    });

    test('submits import receipt and updates providers', () async {
      final batchProvider = BatchProvider(initial: []);
      final importProvider = ImportProvider(batchProvider, initial: []);
      addTearDown(batchProvider.dispose);
      addTearDown(importProvider.dispose);

      final vm = ImportFormViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.setSupplier(supplier);
      vm.setRice(rice1, []);
      vm.setManufactureDate(fixedDate);
      vm.setExpiryDate(fixedDate.add(const Duration(days: 200)));

      final result = await vm.submitImport(
        importProvider: importProvider,
        quantityText: '100',
        purchasePriceText: '18000',
        batchCodeInput: 'LO-TEST-001',
      );

      expect(result.success, isTrue);
      expect(importProvider.receipts.length, 1);
      expect(importProvider.receipts.single.batchCode, 'LO-TEST-001');
      expect(batchProvider.batches.single.quantity, 100);
    });

    test('rejects submit when fields are missing or invalid', () async {
      final batchProvider = BatchProvider(initial: []);
      final importProvider = ImportProvider(batchProvider, initial: []);
      addTearDown(batchProvider.dispose);
      addTearDown(importProvider.dispose);

      final vm = ImportFormViewModel();
      addTearDown(vm.dispose);

      // Missing supplier & rice
      final r1 = await vm.submitImport(
        importProvider: importProvider,
        quantityText: '10',
        purchasePriceText: '1000',
        batchCodeInput: 'LO-1',
      );
      expect(r1.success, isFalse);
      expect(r1.message, contains('nhà cung cấp'));

      vm.setSupplier(supplier);
      vm.setRice(rice1, []);

      // Invalid quantity
      final r2 = await vm.submitImport(
        importProvider: importProvider,
        quantityText: '-10',
        purchasePriceText: '1000',
        batchCodeInput: 'LO-1',
      );
      expect(r2.success, isFalse);
      expect(r2.message, contains('Số lượng phải lớn hơn 0'));
    });
  });

  group('ExportFormViewModel', () {
    test('converts units to kg accurately', () {
      final vm = ExportFormViewModel();
      addTearDown(vm.dispose);

      // Index 0: Kg
      vm.setUnitIndex(0);
      expect(vm.calculateQuantityKg('10'), 10);

      // Index 1: Bao (50kg)
      vm.setUnitIndex(1);
      expect(vm.calculateQuantityKg('10'), 500);

      // Index 2: Tạ (100kg)
      vm.setUnitIndex(2);
      expect(vm.calculateQuantityKg('10'), 1000);

      // Index 3: Tấn (1000kg)
      vm.setUnitIndex(3);
      expect(vm.calculateQuantityKg('2.5'), 2500);
    });

    test('validates quantity against available stock in BatchProvider', () {
      final batch = BatchModel(
        id: 'b-1',
        code: 'LO-1',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 200,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 30)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batch]);
      addTearDown(batchProvider.dispose);

      final vm = ExportFormViewModel();
      addTearDown(vm.dispose);

      vm.setRice(rice1);
      vm.setUnitIndex(0); // Kg

      // Stock is 200kg
      expect(vm.validateQuantity('150', batchProvider), isNull);
      expect(vm.validateQuantity('250', batchProvider),
          contains('Vượt quá tồn kho khả dụng'));

      // If unit is Bao (50kg), 5 bao = 250kg -> should fail
      vm.setUnitIndex(1);
      expect(vm.validateQuantity('5', batchProvider),
          contains('Vượt quá tồn kho khả dụng'));
      expect(vm.validateQuantity('4', batchProvider), isNull);
    });

    test('previews FEFO and confirms export successfully', () async {
      final batchA = BatchModel(
        id: 'b-a',
        code: 'LO-A',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 100,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 10)),
        status: BatchStatus.available,
      );
      final batchB = BatchModel(
        id: 'b-b',
        code: 'LO-B',
        riceId: rice1.id,
        riceName: rice1.name,
        quantity: 150,
        importDate: fixedDate,
        manufactureDate: fixedDate,
        expiryDate: fixedDate.add(const Duration(days: 40)),
        status: BatchStatus.available,
      );
      final batchProvider = BatchProvider(initial: [batchA, batchB]);
      final exportProvider = ExportProvider(batchProvider, initial: []);
      addTearDown(batchProvider.dispose);
      addTearDown(exportProvider.dispose);

      final vm = ExportFormViewModel();
      addTearDown(vm.dispose);

      vm.setCustomer(customer);
      vm.setRice(rice1);
      vm.setUnitIndex(0); // Kg

      // Export 120 kg -> should take 100 from LO-A and 20 from LO-B
      final preview = vm.previewFefo(
        exportProvider: exportProvider,
        batchProvider: batchProvider,
        quantityText: '120',
        sellingPriceText: '25000',
      );

      expect(preview.success, isTrue);
      expect(preview.result, isNotNull);
      expect(preview.result!.allocations.length, 2);
      expect(preview.result!.allocations.first.batchCode, 'LO-A');
      expect(preview.result!.allocations.first.allocatedQuantity, 100);
      expect(preview.result!.allocations.last.batchCode, 'LO-B');
      expect(preview.result!.allocations.last.allocatedQuantity, 20);

      // Confirm export
      final confirm = await vm.confirmExport(
        exportProvider: exportProvider,
        note: 'Giao gấp trong ngày',
      );

      expect(confirm.success, isTrue);
      expect(exportProvider.receipts.length, 1);
      expect(exportProvider.receipts.single.note, 'Giao gấp trong ngày');
      expect(exportProvider.receipts.single.totalAmount, 120 * 25000);
      expect(batchProvider.totalStockForRice(rice1.id), 130);
    });
  });

  group('OcrInvoiceViewModel', () {
    test('parses and extracts invoice fields into review state', () {
      final vm = OcrInvoiceViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      final sampleText = '''
HOÁ ĐƠN GIÁ TRỊ GIA TĂNG
Đơn vị bán: ${supplier.name}
Tên hàng hoá: ${rice1.name}
Số lượng: 1250 kg
Đơn giá: 18500 đ
Số lô: LO-OCR-999
HSD: 25/12/2026
''';

      vm.parseAndExtract(
        rawText: sampleText,
        suppliers: [supplier],
        rices: [rice1],
      );

      expect(vm.selectedSupplier?.id, supplier.id);
      expect(vm.selectedRice?.id, rice1.id);
      expect(vm.suggestedQuantityText, '1250');
      expect(vm.suggestedPurchasePriceText, '18500');
      expect(vm.suggestedBatchCode, 'LO-OCR-999');
    });

    test('validates and submits OCR import receipt successfully', () async {
      final batchProvider = BatchProvider(initial: []);
      final importProvider = ImportProvider(batchProvider, initial: []);
      addTearDown(batchProvider.dispose);
      addTearDown(importProvider.dispose);

      final vm = OcrInvoiceViewModel(clock: () => fixedDate);
      addTearDown(vm.dispose);

      vm.setSupplier(supplier);
      vm.setRice(rice1);
      vm.setManufactureDate(fixedDate);
      vm.setExpiryDate(fixedDate.add(const Duration(days: 300)));

      final submitResult = await vm.submit(
        importProvider: importProvider,
        quantityText: '500',
        priceText: '16000',
        batchCodeText: 'LO-OCR-500',
      );

      expect(submitResult.success, isTrue);
      expect(submitResult.receiptCode, isNotNull);
      expect(importProvider.receipts.length, 1);
      expect(importProvider.receipts.single.quantity, 500);
      expect(importProvider.receipts.single.batchCode, 'LO-OCR-500');
      expect(batchProvider.batches.single.quantity, 500);
    });

    test('rejects OCR submit on missing supplier or invalid numbers', () async {
      final batchProvider = BatchProvider(initial: []);
      final importProvider = ImportProvider(batchProvider, initial: []);
      addTearDown(batchProvider.dispose);
      addTearDown(importProvider.dispose);

      final vm = OcrInvoiceViewModel();
      addTearDown(vm.dispose);

      final res1 = await vm.submit(
        importProvider: importProvider,
        quantityText: '10',
        priceText: '1000',
        batchCodeText: 'LO-1',
      );
      expect(res1.success, isFalse);
      expect(res1.message, contains('nhà cung cấp'));

      vm.setSupplier(supplier);
      vm.setRice(rice1);

      final res2 = await vm.submit(
        importProvider: importProvider,
        quantityText: '0',
        priceText: '1000',
        batchCodeText: 'LO-1',
      );
      expect(res2.success, isFalse);
      expect(res2.message, contains('Số lượng phải lớn hơn 0'));
    });
  });
}
