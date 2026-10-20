import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';

/// ViewModel for Inventory Screen filtering, low-stock counting and metrics calculation.
class InventoryViewModel extends ChangeNotifier {
  String _query = '';
  String _selectedFilter = 'Tất cả';

  static const List<String> filterOptions = [
    'Tất cả',
    'ST25',
    'Jasmine',
    'Bao 50kg',
    'Cần nhập thêm',
    'Đủ hàng',
  ];

  String get query => _query;
  String get selectedFilter => _selectedFilter;

  void setQuery(String q) {
    if (_query == q) return;
    _query = q;
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  int? getBadgeCount(
    String filter,
    List<RiceModel> allRices,
    BatchProvider batchProvider,
  ) {
    if (filter == 'Cần nhập thêm') {
      return allRices
          .where((r) => batchProvider.totalStockForRice(r.id) <= r.minimumStock)
          .length;
    }
    return null;
  }

  List<RiceModel> filterRices({
    required List<RiceModel> allRices,
    required BatchProvider batchProvider,
  }) {
    final lowerQuery = _query.trim().toLowerCase();

    final searched = lowerQuery.isEmpty
        ? allRices
        : allRices.where((rice) {
            return rice.name.toLowerCase().contains(lowerQuery) ||
                rice.code.toLowerCase().contains(lowerQuery) ||
                rice.category.toLowerCase().contains(lowerQuery);
          }).toList(growable: false);

    return searched.where((rice) {
      final stock = batchProvider.totalStockForRice(rice.id);
      final isLow = stock <= rice.minimumStock;

      switch (_selectedFilter) {
        case 'ST25':
          return rice.name.toLowerCase().contains('st25') ||
              rice.code.toLowerCase().contains('st25');
        case 'Jasmine':
          return rice.name.toLowerCase().contains('jasmine');
        case 'Bao 50kg':
          return true;
        case 'Cần nhập thêm':
          return isLow;
        case 'Đủ hàng':
          return !isLow;
        case 'Tất cả':
        default:
          return true;
      }
    }).toList(growable: false);
  }

  ({double totalKg, double totalTons, int totalBags}) calculateMetrics({
    required List<RiceModel> rices,
    required BatchProvider batchProvider,
  }) {
    final totalKg = rices.fold<double>(
      0.0,
      (sum, rice) => sum + batchProvider.totalStockForRice(rice.id),
    );
    final totalTons = totalKg / 1000.0;
    final totalBags = (totalKg / 50.0).round();
    return (totalKg: totalKg, totalTons: totalTons, totalBags: totalBags);
  }
}
