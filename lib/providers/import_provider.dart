import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/repositories/contracts/crud_repository.dart';
import 'package:smart_rice_warehouse/repositories/firestore/inventory_transaction_repository.dart';

class ImportProvider extends ChangeNotifier {
  ImportProvider(
    this._batchProvider, {
    List<ImportReceiptModel>? initial,
    this.onPersist,
    this.repository,
    this.transactionRepository,
  }) : _receipts = List<ImportReceiptModel>.from(
          initial ?? MockData.importReceipts,
        ) {
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  final List<ImportReceiptModel> _receipts;
  final BatchProvider _batchProvider;
  final ValueChanged<List<ImportReceiptModel>>? onPersist;
  final CrudRepository<ImportReceiptModel>? repository;
  final InventoryTransactionRepository? transactionRepository;
  StreamSubscription<List<ImportReceiptModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<ImportReceiptModel> get receipts =>
      List<ImportReceiptModel>.unmodifiable(_receipts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteReceipts) {
        _receipts
          ..clear()
          ..addAll(remoteReceipts);
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(receipts);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ phiếu nhập: $error';
        notifyListeners();
      },
    );
  }

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

  Future<bool> createImportReceiptOnline({
    required ImportReceiptModel receipt,
    required BatchModel batch,
    String performedBy = 'system',
  }) async {
    if (transactionRepository == null) {
      return createImportReceipt(receipt: receipt, batch: batch);
    }
    try {
      await transactionRepository!.confirmImportReceipt(
        receipt: receipt,
        batchToCreateOrUpdate: batch,
        performedBy: performedBy,
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể tạo phiếu nhập: $error';
      notifyListeners();
      return false;
    }
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

    if (transactionRepository != null) {
      unawaited(createImportReceiptOnline(receipt: receipt, batch: batch));
      return true;
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
