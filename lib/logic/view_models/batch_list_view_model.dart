import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/services/excel_export_service.dart';

/// ViewModel for Batch List filtering, metrics calculation and Excel export.
class BatchListViewModel extends ChangeNotifier {
  BatchListViewModel({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  String _query = '';
  String _selectedFilter = 'Tất cả';

  static const List<String> filterOptions = [
    'Tất cả',
    'ST25',
    'Jasmine',
    'Bao 50kg',
    'Cần ưu tiên xuất',
    'Còn hàng',
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

  int? getBadgeCount(String filter, List<BatchModel> allBatches) {
    if (filter == 'Cần ưu tiên xuất') {
      final now = _clock();
      return allBatches.where((b) {
        final days = b.expiryDate.difference(now).inDays;
        return days <= 30 && b.quantity > 0 && b.status != BatchStatus.expired;
      }).length;
    }
    return null;
  }

  List<BatchModel> filterBatches(List<BatchModel> allBatches) {
    final now = _clock();
    final lowerQuery = _query.trim().toLowerCase();

    final searched = lowerQuery.isEmpty
        ? allBatches
        : allBatches.where((b) {
            return b.code.toLowerCase().contains(lowerQuery) ||
                b.riceName.toLowerCase().contains(lowerQuery) ||
                (b.locationName != null &&
                    b.locationName!.toLowerCase().contains(lowerQuery)) ||
                (b.supplierName != null &&
                    b.supplierName!.toLowerCase().contains(lowerQuery));
          }).toList(growable: false);

    return searched.where((batch) {
      final daysUntilExpiry = batch.expiryDate.difference(now).inDays;

      switch (_selectedFilter) {
        case 'ST25':
          return batch.riceName.toLowerCase().contains('st25') ||
              batch.code.toLowerCase().contains('st25');
        case 'Jasmine':
          return batch.riceName.toLowerCase().contains('jasmine');
        case 'Bao 50kg':
          return true;
        case 'Cần ưu tiên xuất':
          return daysUntilExpiry <= 30 &&
              batch.quantity > 0 &&
              batch.status != BatchStatus.expired;
        case 'Còn hàng':
          return batch.status == BatchStatus.available && batch.quantity > 0;
        case 'Tất cả':
        default:
          return true;
      }
    }).toList(growable: false);
  }

  ({double totalKg, double totalTons, int totalBags}) calculateMetrics(
    List<BatchModel> batches,
  ) {
    final totalKg = batches.fold<double>(0.0, (sum, b) => sum + b.quantity);
    final totalTons = totalKg / 1000.0;
    final totalBags = (totalKg / 50.0).round();
    return (totalKg: totalKg, totalTons: totalTons, totalBags: totalBags);
  }

  Future<bool> exportExcel(
      List<BatchModel> batches, List<RiceModel> rices) async {
    try {
      await ExcelExportService.exportInventoryReport(batches, rices);
      return true;
    } catch (_) {
      return false;
    }
  }
}
