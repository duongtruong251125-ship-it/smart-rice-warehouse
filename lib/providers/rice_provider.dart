import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';

class RiceProvider extends ChangeNotifier {
  RiceProvider() : _rices = List<RiceModel>.from(MockData.rices);

  final List<RiceModel> _rices;

  List<RiceModel> get rices => List<RiceModel>.unmodifiable(_rices);

  RiceModel? findById(String id) {
    for (final rice in _rices) {
      if (rice.id == id) {
        return rice;
      }
    }
    return null;
  }

  bool isCodeExists(String code, {String? excludeId}) {
    final normalizedCode = code.trim().toLowerCase();
    return _rices.any(
      (rice) =>
          rice.id != excludeId &&
          rice.code.trim().toLowerCase() == normalizedCode,
    );
  }

  bool addRice(RiceModel rice) {
    if (isCodeExists(rice.code)) {
      return false;
    }

    _rices.add(rice);
    notifyListeners();
    return true;
  }

  bool updateRice(RiceModel rice) {
    final index = _rices.indexWhere((item) => item.id == rice.id);
    if (index == -1 || isCodeExists(rice.code, excludeId: rice.id)) {
      return false;
    }

    _rices[index] = rice;
    notifyListeners();
    return true;
  }

  bool deleteRice(String id) {
    final removedCount = _rices.length;
    _rices.removeWhere((rice) => rice.id == id);
    if (_rices.length == removedCount) {
      return false;
    }

    notifyListeners();
    return true;
  }

  List<RiceModel> searchRice(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return rices;
    }

    return _rices
        .where(
          (rice) =>
              rice.code.toLowerCase().contains(normalizedQuery) ||
              rice.name.toLowerCase().contains(normalizedQuery) ||
              rice.category.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
