import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';

class WarehouseProvider extends ChangeNotifier {
  WarehouseProvider() {
    _locations = List<WarehouseLocationModel>.from(MockData.warehouseLocations);
  }

  late List<WarehouseLocationModel> _locations;

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
      return _locations.firstWhere((item) => item.code.toLowerCase() == code.toLowerCase());
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

  void addLocation(WarehouseLocationModel location) {
    _locations.add(location);
    notifyListeners();
  }

  void updateLocation(WarehouseLocationModel location) {
    final index = _locations.indexWhere((item) => item.id == location.id);
    if (index >= 0) {
      _locations[index] = location;
      notifyListeners();
    }
  }

  void updateBatchCount(String locationId, int delta) {
    final index = _locations.indexWhere((item) => item.id == locationId);
    if (index >= 0) {
      final current = _locations[index];
      final newCount = (current.currentBatchCount + delta).clamp(0, 9999);
      _locations[index] = current.copyWith(currentBatchCount: newCount);
      notifyListeners();
    }
  }
}
