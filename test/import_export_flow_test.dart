import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';

void main() {
  test('import increases stock and export decreases stock safely', () {
    final batchProvider = BatchProvider();
    final importProvider = ImportProvider(batchProvider);
    final exportProvider = ExportProvider(batchProvider);
    const riceId = 'rice-st25';
    const riceName = 'Gạo ST25';
    final now = DateTime.now();
    final initialStock = batchProvider.totalStockForRice(riceId);

    final importCreated = importProvider.createImportReceipt(
      receipt: ImportReceiptModel(
        id: 'test-import',
        code: 'PN-TEST',
        supplierId: 'supplier-lua-viet',
        supplierName: 'Công ty Lúa Việt',
        date: now,
        riceId: riceId,
        riceName: riceName,
        quantity: 10,
        purchasePrice: 28000,
        totalAmount: 280000,
        batchCode: 'LO-TEST-IMPORT',
        manufactureDate: now,
        expiryDate: DateTime(now.year + 1, now.month, now.day),
      ),
      batch: BatchModel(
        id: 'test-batch',
        code: 'LO-TEST-IMPORT',
        riceId: riceId,
        riceName: riceName,
        quantity: 10,
        importDate: now,
        manufactureDate: now,
        expiryDate: DateTime(now.year + 1, now.month, now.day),
        status: BatchStatus.available,
      ),
    );

    expect(importCreated, isTrue);
    expect(batchProvider.totalStockForRice(riceId), initialStock + 10);

    final exportCreated = exportProvider.createExportReceipt(
      ExportReceiptModel(
        id: 'test-export',
        code: 'PX-TEST',
        customerId: 'customer-minh-phat',
        customerName: 'Đại lý Minh Phát',
        date: now,
        riceId: riceId,
        riceName: riceName,
        quantity: 4,
        sellingPrice: 35000,
        totalAmount: 140000,
        note: '',
      ),
    );

    expect(exportCreated, isTrue);
    expect(batchProvider.totalStockForRice(riceId), initialStock + 6);

    final stockBeforeRejectedExport = batchProvider.totalStockForRice(riceId);
    final receiptCountBeforeRejectedExport = exportProvider.receipts.length;
    final oversizedExportCreated = exportProvider.createExportReceipt(
      ExportReceiptModel(
        id: 'test-export-oversized',
        code: 'PX-TEST-OVERSIZED',
        customerId: 'customer-minh-phat',
        customerName: 'Đại lý Minh Phát',
        date: now,
        riceId: riceId,
        riceName: riceName,
        quantity: stockBeforeRejectedExport + 1,
        sellingPrice: 35000,
        totalAmount: (stockBeforeRejectedExport + 1) * 35000,
        note: '',
      ),
    );

    expect(oversizedExportCreated, isFalse);
    expect(batchProvider.totalStockForRice(riceId), stockBeforeRejectedExport);
    expect(exportProvider.receipts.length, receiptCountBeforeRejectedExport);
    expect(
      batchProvider.batches.every((batch) => batch.quantity >= 0),
      isTrue,
    );
  });
}
