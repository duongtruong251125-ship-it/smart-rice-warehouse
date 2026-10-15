import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/core/services/image_storage_service.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';

class RiceProvider extends ChangeNotifier {
  RiceProvider({List<RiceModel>? initial, this.onPersist})
      : _rices = List<RiceModel>.from(initial ?? MockData.rices);

  final List<RiceModel> _rices;
  final ValueChanged<List<RiceModel>>? onPersist;

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
    onPersist?.call(rices);
    notifyListeners();
    return true;
  }

  bool updateRice(RiceModel rice) {
    final index = _rices.indexWhere((item) => item.id == rice.id);
    if (index == -1 || isCodeExists(rice.code, excludeId: rice.id)) {
      return false;
    }

    _rices[index] = rice;
    onPersist?.call(rices);
    notifyListeners();
    return true;
  }

  bool deleteRice(String id, {bool Function(String id)? isReferenced}) {
    if (isReferenced?.call(id) ?? false) return false;
    final index = _rices.indexWhere((rice) => rice.id == id);
    if (index == -1) {
      return false;
    }

    final removedRice = _rices.removeAt(index);
    if (removedRice.imagePath != null && removedRice.imagePath!.isNotEmpty) {
      ImageStorageService.deleteImageIfExists(removedRice.imagePath);
    }

    onPersist?.call(rices);
    notifyListeners();
    return true;
  }

  List<RiceModel> searchRice(String query) {
    return filterRices(query: query);
  }

  List<RiceModel> filterRices({
    String query = '',
    Set<String> selectedCharacteristicIds = const {},
    List<RiceCharacteristicModel> allCharacteristics = const [],
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return _rices.where((rice) {
      final matchesQuery = normalizedQuery.isEmpty ||
          rice.code.toLowerCase().contains(normalizedQuery) ||
          rice.name.toLowerCase().contains(normalizedQuery) ||
          rice.category.toLowerCase().contains(normalizedQuery) ||
          allCharacteristics
              .where((c) => rice.characteristicIds.contains(c.id))
              .any((c) => c.name.toLowerCase().contains(normalizedQuery));

      if (!matchesQuery) return false;

      if (selectedCharacteristicIds.isNotEmpty) {
        final hasAllSelected = selectedCharacteristicIds
            .every((charId) => rice.characteristicIds.contains(charId));
        if (!hasAllSelected) return false;
      }

      return true;
    }).toList(growable: false);
  }

  void removeCharacteristicFromAll(String characteristicId) {
    bool changed = false;
    for (int i = 0; i < _rices.length; i++) {
      if (_rices[i].characteristicIds.contains(characteristicId)) {
        final updatedIds = List<String>.from(_rices[i].characteristicIds)
          ..remove(characteristicId);
        _rices[i] = _rices[i].copyWith(characteristicIds: updatedIds);
        changed = true;
      }
    }
    if (changed) {
      onPersist?.call(rices);
      notifyListeners();
    }
  }

  int countRicesWithCharacteristic(String characteristicId) {
    return _rices
        .where((r) => r.characteristicIds.contains(characteristicId))
        .length;
  }
}
