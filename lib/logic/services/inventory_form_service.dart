import 'package:uuid/uuid.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';

/// Creates warehouse documents without depending on form controllers or widgets.
class InventoryFormService {
  InventoryFormService({DateTime Function()? clock, String Function()? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? const Uuid().v4;

  final DateTime Function() _clock;
  final String Function() _newId;

  Future<bool> submitImport({
    required ImportProvider provider,
    required SupplierModel supplier,
    required RiceModel rice,
    required double quantity,
    required double purchasePrice,
    required String batchCode,
    required DateTime manufactureDate,
    required DateTime expiryDate,
    String? existingBatchId,
    String performedBy = 'system',
  }) async {
    final now = _clock();
    final id = _newId();
    final receipt = ImportReceiptModel(
      id: id,
      code: provider.generateReceiptCode(),
      supplierId: supplier.id,
      supplierName: supplier.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalAmount: quantity * purchasePrice,
      batchCode: batchCode,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
    );
    final batch = BatchModel(
      id: existingBatchId ?? id,
      code: batchCode,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      importDate: now,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
      status: expiryDate.isBefore(DateTime(now.year, now.month, now.day))
          ? BatchStatus.expired
          : BatchStatus.available,
      supplierId: supplier.id,
      supplierName: supplier.name,
    );
    return await provider.createImportReceipt(
      receipt: receipt,
      batch: batch,
      performedBy: performedBy,
    );
  }

  Future<bool> submitExport({
    required ExportProvider provider,
    required CustomerModel customer,
    required RiceModel rice,
    required double quantity,
    required double sellingPrice,
    required List<BatchAllocation> allocations,
    String note = '',
    String performedBy = 'system',
  }) async {
    final receipt = ExportReceiptModel(
      id: _newId(),
      code: provider.generateReceiptCode(),
      customerId: customer.id,
      customerName: customer.name,
      date: _clock(),
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      sellingPrice: sellingPrice,
      totalAmount: quantity * sellingPrice,
      note: note.trim(),
      allocations: allocations,
    );
    return await provider.createExportReceipt(
      receipt,
      performedBy: performedBy,
    );
  }

  static const unitMultipliers = [1.0, 50.0, 100.0, 1000.0];

  static double quantityInKg(double input, int unitIndex) =>
      input * unitMultipliers[unitIndex];

  static double totalAmount(double quantityKg, double pricePerKg) =>
      quantityKg > 0 && pricePerKg >= 0 ? quantityKg * pricePerKg : 0;
}
