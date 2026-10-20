import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/batch_location_writer.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/providers/lifecycle_notifier.dart';

class BatchProvider extends LifecycleNotifier {
  BatchProvider({
    List<BatchModel>? initial,
    this.onPersist,
    this.repository,
  }) : _batches = List<BatchModel>.from(
          initial ?? DefaultDataRegistry.provider?.batches ?? const [],
        ) {
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  final List<BatchModel> _batches;
  final ValueChanged<List<BatchModel>>? onPersist;
  final CrudRepository<BatchModel>? repository;
  StreamSubscription<List<BatchModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;
  RepositoryException? _lastFailure;
  RepositoryException? get lastFailure => _lastFailure;
  int _streamRevision = 0;
  final Set<String> _moving = {};

  List<BatchModel> get batches => List<BatchModel>.unmodifiable(_batches);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  Future<void> _subscriptionWork = Future<void>.value();

  void _readFailure(Object error, int revision) {
    if (isDisposed || revision != _streamRevision) return;
    _lastFailure = error is RepositoryException
        ? error
        : RepositoryException('Không thể đồng bộ danh sách lô hàng.',
            cause: error);
    _isLoading = false;
    _errorMessage = 'Không thể đồng bộ danh sách lô hàng: $error';
    notifyListeners();
  }

  void _subscribeToFirestore() {
    final revision = ++_streamRevision;
    final previous = _subscription;
    _subscription = null;
    _isLoading = true;
    _subscriptionWork = _subscriptionWork.then((_) async {
      await previous?.cancel();
      if (isDisposed || revision != _streamRevision) return;
      _subscription = repository!.watchAll().listen(
        (remoteBatches) {
          if (isDisposed || revision != _streamRevision) return;
          _batches
            ..clear()
            ..addAll(remoteBatches);
          _isLoading = false;
          _errorMessage = null;
          _lastFailure = null;
          _persist();
          notifyListeners();
        },
        onError: (Object error) => _readFailure(error, revision),
      );
    }).catchError((Object error) => _readFailure(error, revision));
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _lastFailure = null;
    notifyListeners();
  }

  void retrySync() {
    if (isDisposed) return;
    _errorMessage = null;
    if (repository != null) {
      _subscribeToFirestore();
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

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

  Future<bool> addBatchOnline(BatchModel batch) async {
    if (repository == null) {
      return addBatch(batch);
    }
    if (isBatchCodeExists(batch.code)) {
      return false;
    }
    try {
      await repository!.create(batch.id, batch);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể tạo lô hàng: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBatchOnline(BatchModel batch) async {
    if (repository == null) {
      return updateBatch(batch);
    }
    try {
      await repository!.update(batch.id, batch);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể cập nhật lô hàng: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignLocationOnline({
    required String batchId,
    required String locationId,
    required String locationName,
  }) async {
    if (isDisposed || _moving.contains(batchId)) return false;
    final batch = findById(batchId);
    if (batch == null) return false;
    if (repository case final BatchLocationWriter writer) {
      _moving.add(batchId);
      try {
        await writer.moveBatch(
            batchId: batchId,
            locationId: locationId,
            locationName: locationName);
        if (isDisposed) return true;
        _errorMessage = null;
        _lastFailure = null;
        return true;
      } catch (error) {
        if (isDisposed) return false;
        _lastFailure = error is RepositoryException
            ? error
            : RepositoryException('Không thể chuyển vị trí.', cause: error);
        _errorMessage = 'Không thể chuyển vị trí lô hàng: $error';
        notifyListeners();
        return false;
      } finally {
        _moving.remove(batchId);
        notifyListeners();
      }
    }
    final updated = batch.copyWith(
      warehouseLocationId: locationId,
      locationName: locationName,
    );
    return updateBatchOnline(updated);
  }

  bool addBatch(BatchModel batch) {
    if (isBatchCodeExists(batch.code)) {
      return false;
    }
    if (repository != null) {
      unawaited(addBatchOnline(batch));
      return true;
    }

    _batches.add(batch);
    _persist();
    notifyListeners();
    return true;
  }

  bool updateBatch(BatchModel batch) {
    if (repository != null) {
      unawaited(updateBatchOnline(batch));
      return true;
    }
    final index = _batches.indexWhere((item) => item.id == batch.id);
    if (index == -1) {
      return false;
    }

    _batches[index] = batch;
    _persist();
    notifyListeners();
    return true;
  }

  /// Gán hoặc chuyển đổi vị trí kho cho lô hàng
  bool assignLocation({
    required String batchId,
    required String locationId,
    required String locationName,
  }) {
    if (repository != null) {
      return false; // UI must await assignLocationOnline.
    }
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

  /// Báo hỏng và giảm tồn lô hàng (local mode)
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

  bool applyFefoAllocations(List<BatchAllocation> allocations) {
    if (allocations.isEmpty) {
      return false;
    }

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
    _persist();
    notifyListeners();
    return true;
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
        batch.status != BatchStatus.qualityHold &&
        !expiryDate.isBefore(today);
  }

  void _persist() => onPersist?.call(batches);

  @override
  void dispose() {
    ++_streamRevision;
    _subscription?.cancel();
    super.dispose();
  }
}
