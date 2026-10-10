import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';

class BatchProvider extends ChangeNotifier {
  BatchProvider({List<BatchModel>? initial, this.onPersist})
      : _batches = List<BatchModel>.from(initial ?? MockData.batches);

  final List<BatchModel> _batches;
  final ValueChanged<List<BatchModel>>? onPersist;

  List<BatchModel> get batches => List<BatchModel>.unmodifiable(_batches);

  double get totalStock => _batches
      .where(_isAvailable)
      .fold(0, (total, batch) => total + batch.quantity);

  double inventoryValue(Iterable<RiceModel> rices) {
    return rices.fold(
      0,
      (total, rice) => total + totalStockForRice(rice.id) * rice.purchasePrice,
    );
  }

  BatchModel? findById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  BatchModel? findByCode(String code) {
    try {
      final normalized = code.trim().toLowerCase();
      return _batches.firstWhere(
        (b) => b.code.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  bool isBatchCodeExists(String code) {
    final normalizedCode = code.trim().toLowerCase();
    return _batches.any(
      (batch) => batch.code.trim().toLowerCase() == normalizedCode,
    );
  }

  bool addBatch(BatchModel batch) {
    if (isBatchCodeExists(batch.code)) {
      return false;
    }

    _batches.add(batch);
    _persist();
    notifyListeners();
    return true;
  }

  bool updateBatch(BatchModel batch) {
    final index = _batches.indexWhere((item) => item.id == batch.id);
    if (index == -1) {
      return false;
    }

    _batches[index] = batch;
    _persist();
    notifyListeners();
    return true;
  }

  /// Gán hoặc chuyển đổi vị trí kho cho lô hàng (Task 1.5)
  bool assignLocation({
    required String batchId,
    required String locationId,
    required String locationName,
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;
    _batches[index] = _batches[index].copyWith(
      warehouseLocationId: locationId,
      locationName: locationName,
    );
    _persist();
    notifyListeners();
    return true;
  }

  /// Điều chỉnh số lượng lô từ kiểm kê (Task 2.5)
  bool adjustQuantity({
    required String batchId,
    required double newQuantity,
    String? reason,
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;
    if (!newQuantity.isFinite || newQuantity < 0) return false;
    final batch = _batches[index];
    _batches[index] = batch.copyWith(
      quantity: newQuantity,
      status: newQuantity == 0 ? BatchStatus.lowStock : batch.status,
    );
    _persist();
    notifyListeners();
    return true;
  }

  /// Báo hỏng và giảm tồn lô hàng (Task 3.4)
  bool reportDamage({
    required String batchId,
    required double damagedQuantity,
  }) {
    final index = _batches.indexWhere((b) => b.id == batchId);
    if (index == -1) return false;
    final batch = _batches[index];
    if (!damagedQuantity.isFinite ||
        damagedQuantity <= 0 ||
        damagedQuantity > batch.quantity) {
      return false;
    }
    final updated = batch.quantity - damagedQuantity;
    _batches[index] = batch.copyWith(
      quantity: updated,
      status: updated == 0 ? BatchStatus.lowStock : batch.status,
    );
    _persist();
    notifyListeners();
    _persist();
    return true;
  }

  List<BatchModel> searchBatches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return batches;
    }

    return _batches
        .where(
          (batch) =>
              batch.code.toLowerCase().contains(normalizedQuery) ||
              batch.riceName.toLowerCase().contains(normalizedQuery) ||
              batch.status.label.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  List<BatchModel> findByRiceId(String riceId) {
    return _batches
        .where((batch) => batch.riceId == riceId)
        .toList(growable: false);
  }

  double totalStockForRice(String riceId) {
    return _batches
        .where((batch) => batch.riceId == riceId && _isAvailable(batch))
        .fold(0, (total, batch) => total + batch.quantity);
  }

  int batchCountForRice(String riceId) {
    return _batches
        .where((batch) => batch.riceId == riceId && _isAvailable(batch))
        .length;
  }

  bool applyFefoAllocations(List<BatchAllocation> allocations) {
    if (allocations.isEmpty) {
      return false;
    }

    // Validate the complete transaction before changing any stock. Grouping by
    // batch also protects against duplicate allocation rows over-deducting it.
    final requestedByBatch = <String, double>{};
    for (final allocation in allocations) {
      if (!allocation.allocatedQuantity.isFinite ||
          allocation.allocatedQuantity <= 0) {
        return false;
      }
      requestedByBatch.update(
        allocation.batchId,
        (value) => value + allocation.allocatedQuantity,
        ifAbsent: () => allocation.allocatedQuantity,
      );
    }

    for (final entry in requestedByBatch.entries) {
      final batch = findById(entry.key);
      if (batch == null ||
          entry.value > batch.quantity ||
          !_isAvailable(batch)) {
        return false;
      }
    }

    for (final entry in requestedByBatch.entries) {
      final index = _batches.indexWhere((item) => item.id == entry.key);
      final batch = _batches[index];
      final updatedQuantity = batch.quantity - entry.value;
      _batches[index] = batch.copyWith(
        quantity: updatedQuantity,
        status: updatedQuantity == 0 ? BatchStatus.lowStock : batch.status,
      );
    }

    notifyListeners();
    _persist();
    return true;
  }

  /// Applies an inventory check as one transaction. If one batch is invalid,
  /// no batch is changed.
  bool adjustQuantities(Map<String, double> quantities) {
    if (quantities.isEmpty) return false;
    for (final entry in quantities.entries) {
      if (findById(entry.key) == null ||
          !entry.value.isFinite ||
          entry.value < 0) {
        return false;
      }
    }
    for (final entry in quantities.entries) {
      final index = _batches.indexWhere((batch) => batch.id == entry.key);
      final batch = _batches[index];
      _batches[index] = batch.copyWith(
        quantity: entry.value,
        status: entry.value == 0 ? BatchStatus.lowStock : batch.status,
      );
    }
    notifyListeners();
    return true;
  }

  bool removeStock({required String riceId, required double quantity}) {
    final result = const FefoService().allocate(
      batches: _batches,
      riceId: riceId,
      quantity: quantity,
    );
    if (!result.isSuccess) {
      return false;
    }
    return applyFefoAllocations(result.allocations);
  }

  bool _isAvailable(BatchModel batch) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      batch.expiryDate.year,
      batch.expiryDate.month,
      batch.expiryDate.day,
    );

    return batch.quantity > 0 &&
        batch.status != BatchStatus.expired &&
        !expiryDate.isBefore(today);
  }

  void _persist() => onPersist?.call(batches);
}
