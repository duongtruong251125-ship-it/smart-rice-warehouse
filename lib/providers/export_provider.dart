import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';

class ExportProvider extends ChangeNotifier {
  ExportProvider(
    this._batchProvider, this._database, {
    List<ExportReceiptModel>? initial,
    this.onPersist,
  }) : _receipts = List<ExportReceiptModel>.from(
          initial ?? MockData.exportReceipts,
        );

  final List<ExportReceiptModel> _receipts;
  BatchProvider _batchProvider;
  final AppDatabase? _database;
  final ValueChanged<List<ExportReceiptModel>>? onPersist;
  final FefoService _fefoService = const FefoService();

  List<ExportReceiptModel> get receipts =>
      List<ExportReceiptModel>.unmodifiable(_receipts);

  int receiptCountOn(DateTime date) {
    return _receipts.where((receipt) => _isSameDate(receipt.date, date)).length;
  }

  double totalAmountForMonth(DateTime month) {
    return _receipts
        .where(
          (receipt) =>
              receipt.date.year == month.year &&
              receipt.date.month == month.month,
        )
        .fold(0, (total, receipt) => total + receipt.totalAmount);
  }

  double quantityOn(DateTime date) {
    return _receipts
        .where((receipt) => _isSameDate(receipt.date, date))
        .fold(0, (total, receipt) => total + receipt.quantity);
  }

  void updateBatchProvider(BatchProvider batchProvider) {
    _batchProvider = batchProvider;
  }

  bool canExport({required String riceId, required double quantity}) {
    if (quantity <= 0) return false;
    final result = previewFefoAllocation(riceId: riceId, quantity: quantity);
    return result.isSuccess;
  }

  /// Tính toán trước phân bổ lô hàng theo nguyên tắc FEFO mà chưa trừ kho
  FefoAllocationResult previewFefoAllocation({
    required String riceId,
    required double quantity,
    DateTime? currentDate,
  }) {
    return _fefoService.allocate(
      batches: _batchProvider.batches,
      riceId: riceId,
      quantity: quantity,
      currentDate: currentDate,
    );
  }

  String generateReceiptCode() {
    return 'PX${(_maxCodeNumber() + 1).toString().padLeft(3, '0')}';
  }

  ExportReceiptModel? findById(String id) {
    try {
      return _receipts.firstWhere((receipt) => receipt.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ExportReceiptModel> searchReceipts(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return receipts;
    return _receipts
        .where(
          (r) =>
              r.code.toLowerCase().contains(normalized) ||
              r.customerName.toLowerCase().contains(normalized) ||
              r.riceName.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  /// Tạo phiếu xuất kho áp dụng thuật toán FEFO
  bool createExportReceipt(ExportReceiptModel receipt) {
    if (receipt.quantity <= 0 ||
        _receipts.any((item) =>
            item.id == receipt.id ||
            item.code.trim().toLowerCase() ==
                receipt.code.trim().toLowerCase())) {
      return false;
    }
    List<BatchAllocation> allocations = receipt.allocations;

    // Nếu phiếu chưa có sẵn allocation, tính toán theo FEFO
    if (allocations.isEmpty) {
      final previewResult = previewFefoAllocation(
        riceId: receipt.riceId,
        quantity: receipt.quantity,
      );
      if (!previewResult.isSuccess) {
        return false;
      }
      allocations = previewResult.allocations;
    }

    final allocatedTotal = allocations.fold<double>(
      0,
      (total, allocation) => total + allocation.allocatedQuantity,
    );
    if ((allocatedTotal - receipt.quantity).abs() > 0.0001 ||
        allocations.any((allocation) {
          final batch = _batchProvider.findById(allocation.batchId);
          return batch == null || batch.riceId != receipt.riceId;
        })) {
      return false;
    }

    // Trừ kho theo từng lô hàng đã phân bổ
    final stockRemoved = _batchProvider.applyFefoAllocations(allocations);
    if (!stockRemoved) {
      return false;
    }

    // Lưu phiếu xuất kèm thông tin chi tiết từng lô
    final finalizedReceipt = ExportReceiptModel(
      id: receipt.id,
      code: receipt.code,
      customerId: receipt.customerId,
      customerName: receipt.customerName,
      date: receipt.date,
      riceId: receipt.riceId,
      riceName: receipt.riceName,
      quantity: receipt.quantity,
      sellingPrice: receipt.sellingPrice,
      totalAmount: receipt.totalAmount,
      note: receipt.note,
      allocations: allocations,
    );

    _receipts.add(finalizedReceipt);
    onPersist?.call(receipts);
    notifyListeners();
    return true;
  }

  int _maxCodeNumber() {
    var maximum = 0;
    for (final receipt in _receipts) {
      final match = RegExp(r'(\d+)$').firstMatch(receipt.code);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value > maximum) {
        maximum = value;
      }
    }
    return maximum;
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
