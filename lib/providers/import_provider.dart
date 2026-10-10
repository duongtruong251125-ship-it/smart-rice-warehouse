import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/data/app_database.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';

class ImportProvider extends ChangeNotifier {
  ImportProvider(
    this._batchProvider, {
    this.database,
    List<ImportReceiptModel>? initial,
    this.onPersist,
  }) : _receipts = List<ImportReceiptModel>.from(
          initial ?? MockData.importReceipts,
        );

  final List<ImportReceiptModel> _receipts;
  final BatchProvider _batchProvider;
  final AppDatabase? database;
  final ValueChanged<List<ImportReceiptModel>>? onPersist;

  List<ImportReceiptModel> get receipts =>
      List<ImportReceiptModel>.unmodifiable(_receipts);

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

  String generateReceiptCode() {
    return 'PN${(_maxCodeNumber() + 1).toString().padLeft(3, '0')}';
  }

  bool createImportReceipt({
    required ImportReceiptModel receipt,
    required BatchModel batch,
  }) {
    if (receipt.quantity <= 0 ||
        batch.quantity <= 0 ||
        receipt.quantity != batch.quantity ||
        _receipts.any((item) =>
            item.id == receipt.id ||
            item.code.trim().toLowerCase() ==
                receipt.code.trim().toLowerCase())) {
      return false;
    }
    if (_batchProvider.isBatchCodeExists(batch.code)) {
      final existingIndex = _batchProvider.batches.indexWhere(
        (item) =>
            item.code.trim().toLowerCase() == batch.code.trim().toLowerCase(),
      );
      if (existingIndex != -1) {
        final existing = _batchProvider.batches[existingIndex];
        final sameLot = existing.riceId == batch.riceId &&
            existing.supplierId == batch.supplierId &&
            _isSameDate(existing.manufactureDate, batch.manufactureDate) &&
            _isSameDate(existing.expiryDate, batch.expiryDate);
        if (!sameLot) return false;
        _batchProvider.updateBatch(
          existing.copyWith(
            quantity: existing.quantity + batch.quantity,
          ),
        );
        _receipts.add(receipt);
        onPersist?.call(receipts);
        notifyListeners();
        return true;
      }
    }

    if (!_batchProvider.addBatch(batch)) {
      return false;
    }

    _receipts.add(receipt);
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
