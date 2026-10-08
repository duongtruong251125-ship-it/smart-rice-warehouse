import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';

class ExportProvider extends ChangeNotifier {
  ExportProvider(this._batchProvider)
      : _receipts = List<ExportReceiptModel>.from(MockData.exportReceipts);

  final List<ExportReceiptModel> _receipts;
  BatchProvider _batchProvider;

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
    return quantity > 0 && _batchProvider.totalStockForRice(riceId) >= quantity;
  }

  String generateReceiptCode() {
    return 'PX${(_maxCodeNumber() + 1).toString().padLeft(3, '0')}';
  }

  bool createExportReceipt(ExportReceiptModel receipt) {
    final stockRemoved = _batchProvider.removeStock(
      riceId: receipt.riceId,
      quantity: receipt.quantity,
    );
    if (!stockRemoved) {
      return false;
    }

    _receipts.add(receipt);
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
