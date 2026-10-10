import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';

class WarehouseService {
  /// Đếm số lô và tổng khối lượng tại từng vị trí kho
  static Map<String, ({int batchCount, double totalWeight})>
      calculateLocationUsage({
    required List<WarehouseLocationModel> locations,
    required List<BatchModel> batches,
  }) {
    final result = <String, ({int batchCount, double totalWeight})>{};

    for (final loc in locations) {
      final locBatches = batches
          .where((b) => b.warehouseLocationId == loc.id && b.quantity > 0);
      final count = locBatches.length;
      final weight = locBatches.fold<double>(0.0, (sum, b) => sum + b.quantity);
      result[loc.id] = (batchCount: count, totalWeight: weight);
    }

    return result;
  }

  /// Lọc các vị trí còn trống hoặc còn sức chứa
  static List<WarehouseLocationModel> findAvailableLocations({
    required List<WarehouseLocationModel> locations,
    required List<BatchModel> batches,
    double requiredCapacity = 0,
  }) {
    final usage =
        calculateLocationUsage(locations: locations, batches: batches);

    return locations.where((loc) {
      if (!loc.isActive) return false;
      final currentUsage = usage[loc.id] ?? (batchCount: 0, totalWeight: 0.0);
      return (loc.capacity - currentUsage.totalWeight) >= requiredCapacity;
    }).toList();
  }
}
