import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/inventory_transactions.dart';
import 'package:smart_rice_warehouse/logic/services/fefo_service.dart';

class ExportProvider extends ChangeNotifier {
  ExportProvider(
    this._batchProvider, {
    List<ExportReceiptModel>? initial,
    this.onPersist,
    this.repository,
    this.transactionRepository,
  }) : _receipts = List<ExportReceiptModel>.from(
          initial ?? DefaultDataRegistry.provider?.exportReceipts ?? const [],
        ) {
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  final List<ExportReceiptModel> _receipts;
  final BatchProvider _batchProvider;
  final ValueChanged<List<ExportReceiptModel>>? onPersist;
  final CrudRepository<ExportReceiptModel>? repository;
  final InventoryTransactions? transactionRepository;
  final FefoService _fefoService = const FefoService();
  StreamSubscription<List<ExportReceiptModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<ExportReceiptModel> get receipts =>
      List<ExportReceiptModel>.unmodifiable(_receipts);
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
        _errorMessage = 'Không thể đồng bộ phiếu xuất: $error';
        notifyListeners();
      },
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void retrySync() {
    _errorMessage = null;
    if (repository != null) {
      _subscription?.cancel();
      _subscribeToFirestore();
      notifyListeners();
    } else {
      notifyListeners();
    }
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

  Future<bool> createExportReceiptOnline(
    ExportReceiptModel receipt, {
    String performedBy = 'system',
  }) async {
    if (transactionRepository == null) {
      return createExportReceipt(receipt);
    }
    List<BatchAllocation> allocations = receipt.allocations;
    if (allocations.isEmpty) {
      final previewResult = previewFefoAllocation(
        riceId: receipt.riceId,
        quantity: receipt.quantity,
      );
      if (!previewResult.isSuccess) {
        _errorMessage = 'Không thể phân bổ lô hàng theo FEFO.';
        notifyListeners();
        return false;
      }
      allocations = previewResult.allocations;
    }

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

    try {
      await transactionRepository!.confirmExportReceipt(
        receipt: finalizedReceipt,
        performedBy: performedBy,
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể tạo phiếu xuất kho: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createExportReceipt(
    ExportReceiptModel receipt, {
    String performedBy = 'system',
  }) async {
    if (receipt.quantity <= 0 ||
        _receipts.any((item) =>
            item.id == receipt.id ||
            item.code.trim().toLowerCase() ==
                receipt.code.trim().toLowerCase())) {
      return false;
    }

    if (transactionRepository != null) {
      return await createExportReceiptOnline(receipt, performedBy: performedBy);
    }

    List<BatchAllocation> allocations = receipt.allocations;

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

    final stockRemoved = _batchProvider.applyFefoAllocations(allocations);
    if (!stockRemoved) {
      return false;
    }

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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
