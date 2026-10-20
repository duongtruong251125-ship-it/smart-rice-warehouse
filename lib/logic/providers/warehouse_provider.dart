import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/providers/lifecycle_notifier.dart';

class WarehouseProvider extends LifecycleNotifier {
  WarehouseProvider({
    List<WarehouseLocationModel>? initial,
    this.onPersist,
    this.repository,
  }) {
    _locations = List<WarehouseLocationModel>.from(
      initial ?? DefaultDataRegistry.provider?.warehouseLocations ?? const [],
    );
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  late List<WarehouseLocationModel> _locations;
  final ValueChanged<List<WarehouseLocationModel>>? onPersist;
  final CrudRepository<WarehouseLocationModel>? repository;
  StreamSubscription<List<WarehouseLocationModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;
  RepositoryException? _lastFailure;
  RepositoryException? get lastFailure => _lastFailure;
  final Set<String> _creatingCodes = {};
  bool get isSavingLocation => _creatingCodes.isNotEmpty;
  int _streamRevision = 0;
  BatchProvider? _trackedBatches;

  List<WarehouseLocationModel> get locations =>
      List<WarehouseLocationModel>.unmodifiable(_locations);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  Future<void> _subscriptionWork = Future<void>.value();

  void _readFailure(Object error, int revision) {
    if (isDisposed || revision != _streamRevision) return;
    _lastFailure = error is RepositoryException
        ? error
        : RepositoryException('Không thể đồng bộ vị trí kho.', cause: error);
    _isLoading = false;
    _errorMessage = 'Không thể đồng bộ vị trí kho: $error';
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
        (remoteLocations) {
          if (isDisposed || revision != _streamRevision) return;
          _locations
            ..clear()
            ..addAll(remoteLocations);
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

  List<String> get zones {
    final set = _locations.map((e) => e.zone).toSet();
    final list = set.toList()..sort();
    return list;
  }

  WarehouseLocationModel? findById(String id) {
    try {
      return _locations.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  WarehouseLocationModel? findByCode(String code) {
    try {
      return _locations
          .firstWhere((item) => item.code.toLowerCase() == code.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  List<WarehouseLocationModel> filter({String? zone, String? keyword}) {
    return _locations.where((item) {
      if (zone != null && zone.isNotEmpty && item.zone != zone) {
        return false;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        final query = keyword.trim().toLowerCase();
        final matchCode = item.code.toLowerCase().contains(query);
        final matchZone = item.zone.toLowerCase().contains(query);
        final matchRack = item.rack.toLowerCase().contains(query);
        final matchShelf = item.shelf.toLowerCase().contains(query);
        if (!matchCode && !matchZone && !matchRack && !matchShelf) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<bool> addLocationOnline(WarehouseLocationModel location) async {
    if (isDisposed) return false;
    if (repository == null) {
      return addLocation(location);
    }
    if (!location.capacity.isFinite ||
        location.capacity <= 0 ||
        findByCode(location.code) != null ||
        _creatingCodes.contains(location.code.trim().toLowerCase())) {
      _errorMessage =
          'Mã vị trí đã tồn tại, đang được lưu hoặc sức chứa không hợp lệ.';
      return false;
    }
    final key = location.code.trim().toLowerCase();
    _creatingCodes.add(key);
    notifyListeners();
    try {
      await repository!.create(location.id, location);
      if (isDisposed) return true;
      _errorMessage = null;
      _lastFailure = null;
      return true;
    } catch (error) {
      if (isDisposed) return false;
      _lastFailure = error is RepositoryException
          ? error
          : RepositoryException('Không thể thêm vị trí kho.', cause: error);
      _errorMessage = 'Không thể thêm vị trí kho: $error';
      notifyListeners();
      return false;
    } finally {
      _creatingCodes.remove(key);
      notifyListeners();
    }
  }

  bool addLocation(WarehouseLocationModel location) {
    if (isDisposed) return false;
    if (!location.capacity.isFinite ||
        location.capacity <= 0 ||
        findByCode(location.code) != null) {
      return false;
    }
    if (repository != null) {
      return false; // Cloud callers must await addLocationOnline.
    }
    _locations.add(location);
    _persist();
    notifyListeners();
    return true;
  }

  /// Moves a batch only when the target is active and has enough capacity,
  /// then derives displayed batch counts from the actual batch collection.
  bool assignBatch({
    required BatchProvider batchProvider,
    required String batchId,
    required String locationId,
  }) {
    if (isDisposed || repository != null || batchProvider.usesFirestore) {
      return false;
    }
    final batch = batchProvider.findById(batchId);
    final location = findById(locationId);
    if (batch == null || location == null || !location.isActive) return false;

    final usedWeight = batchProvider.batches
        .where((item) =>
            item.id != batch.id &&
            item.warehouseLocationId == location.id &&
            item.quantity > 0)
        .fold<double>(0, (total, item) => total + item.quantity);
    if (usedWeight + batch.quantity > location.capacity) return false;

    final moved = batchProvider.assignLocation(
      batchId: batch.id,
      locationId: location.id,
      locationName: location.fullDisplayName,
    );
    if (!moved) return false;
    _synchronizeCounts(batchProvider);
    return true;
  }

  Future<bool> assignBatchOnline(
      {required BatchProvider batchProvider,
      required String batchId,
      required String locationId}) async {
    if (isDisposed) return false;
    if (repository == null && !batchProvider.usesFirestore) {
      return assignBatch(
          batchProvider: batchProvider,
          batchId: batchId,
          locationId: locationId);
    }
    final batch = batchProvider.findById(batchId);
    final location = findById(locationId);
    final used = batchProvider.batches
        .where((item) =>
            item.id != batchId &&
            item.warehouseLocationId == locationId &&
            item.quantity > 0)
        .fold<double>(0, (sum, item) => sum + item.quantity);
    if (batch == null ||
        location == null ||
        !location.isActive ||
        !location.capacity.isFinite ||
        used + batch.quantity > location.capacity) {
      _errorMessage = 'Vị trí không hoạt động hoặc không đủ sức chứa.';
      notifyListeners();
      return false;
    }
    if (_trackedBatches != batchProvider) {
      _trackedBatches?.removeListener(_onBatchChange);
      _trackedBatches = batchProvider;
      batchProvider.addListener(_onBatchChange);
    }
    final moved = await batchProvider.assignLocationOnline(
        batchId: batchId,
        locationId: locationId,
        locationName: location.fullDisplayName);
    if (isDisposed) return moved;
    if (!moved) {
      _errorMessage = batchProvider.errorMessage ?? 'Không thể chuyển vị trí.';
      _lastFailure = batchProvider.lastFailure;
      notifyListeners();
      return false;
    }
    _errorMessage = null;
    _synchronizeCounts(batchProvider);
    return true;
  }

  void _onBatchChange() {
    if (!isDisposed && _trackedBatches != null) {
      _synchronizeCounts(_trackedBatches!);
    }
  }

  void _synchronizeCounts(BatchProvider batchProvider) {
    if (isDisposed) return;
    for (var index = 0; index < _locations.length; index++) {
      final location = _locations[index];
      final count = batchProvider.batches
          .where((batch) =>
              batch.warehouseLocationId == location.id && batch.quantity > 0)
          .length;
      _locations[index] = location.copyWith(currentBatchCount: count);
    }
    notifyListeners();
    _persist();
  }

  void _persist() => onPersist?.call(locations);

  @override
  void dispose() {
    ++_streamRevision;
    _trackedBatches?.removeListener(_onBatchChange);
    _subscription?.cancel();
    super.dispose();
  }
}
