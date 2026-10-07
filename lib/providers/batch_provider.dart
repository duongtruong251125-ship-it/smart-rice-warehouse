import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';

class BatchProvider extends ChangeNotifier {
  BatchProvider() : _batches = List<BatchModel>.from(MockData.batches);

  final List<BatchModel> _batches;

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
    notifyListeners();
    return true;
  }

  bool updateBatch(BatchModel batch) {
    final index = _batches.indexWhere((item) => item.id == batch.id);
    if (index == -1) {
      return false;
    }

    _batches[index] = batch;
    notifyListeners();
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

  bool removeStock({required String riceId, required double quantity}) {
    const tolerance = 0.000000001;
    if (quantity <= 0 || totalStockForRice(riceId) + tolerance < quantity) {
      return false;
    }

    var remainingQuantity = quantity;
    for (var index = 0; index < _batches.length; index++) {
      final batch = _batches[index];
      if (batch.riceId != riceId || !_isAvailable(batch)) {
        continue;
      }

      final deductedQuantity = batch.quantity < remainingQuantity
          ? batch.quantity
          : remainingQuantity;
      final updatedQuantity = batch.quantity - deductedQuantity;
      _batches[index] = batch.copyWith(
        quantity: updatedQuantity,
        status: updatedQuantity == 0 ? BatchStatus.lowStock : batch.status,
      );
      remainingQuantity -= deductedQuantity;

      if (remainingQuantity <= tolerance) {
        notifyListeners();
        return true;
      }
    }

    return false;
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
}
