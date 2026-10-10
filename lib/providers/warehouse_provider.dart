import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';

class WarehouseProvider extends ChangeNotifier {
  WarehouseProvider({
    List<WarehouseLocationModel>? initial,
    this.onPersist,
  }) {
    _locations = List<WarehouseLocationModel>.from(
      initial ?? MockData.warehouseLocations,
    );
  }

  late List<WarehouseLocationModel> _locations;
  final ValueChanged<List<WarehouseLocationModel>>? onPersist;

  List<WarehouseLocationModel> get locations =>
      List<WarehouseLocationModel>.unmodifiable(_locations);

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

  bool addLocation(WarehouseLocationModel location) {
    if (!location.capacity.isFinite ||
        location.capacity <= 0 ||
        findByCode(location.code) != null) {
      return false;
    }
    _locations.add(location);
    _persist();
    notifyListeners();
    return true;
  }

  void updateLocation(WarehouseLocationModel location) {
    final index = _locations.indexWhere((item) => item.id == location.id);
    if (index >= 0) {
      _locations[index] = location;
      _persist();
      notifyListeners();
    }
  }

  void updateBatchCount(String locationId, int delta) {
    final index = _locations.indexWhere((item) => item.id == locationId);
    if (index >= 0) {
      final current = _locations[index];
      final newCount = (current.currentBatchCount + delta).clamp(0, 9999);
      _locations[index] = current.copyWith(currentBatchCount: newCount);
      _persist();
      notifyListeners();
    }
  }

  /// Moves a batch only when the target is active and has enough capacity,
  /// then derives displayed batch counts from the actual batch collection.
  bool assignBatch({
    required BatchProvider batchProvider,
    required String batchId,
    required String locationId,
  }) {
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

  void _synchronizeCounts(BatchProvider batchProvider) {
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
}
