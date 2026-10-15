import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';

class RiceCharacteristicProvider extends ChangeNotifier {
  RiceCharacteristicProvider({
    List<RiceCharacteristicModel>? initial,
    this.onPersist,
  }) : _characteristics = List<RiceCharacteristicModel>.from(
          initial ?? MockData.defaultCharacteristics,
        );

  final List<RiceCharacteristicModel> _characteristics;
  final ValueChanged<List<RiceCharacteristicModel>>? onPersist;

  List<RiceCharacteristicModel> get characteristics =>
      List<RiceCharacteristicModel>.unmodifiable(_characteristics);

  RiceCharacteristicModel? findById(String id) {
    for (final char in _characteristics) {
      if (char.id == id) {
        return char;
      }
    }
    return null;
  }

  bool isNameExists(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    return _characteristics.any(
      (c) => c.id != excludeId && c.name.trim().toLowerCase() == normalized,
    );
  }

  bool addCharacteristic(RiceCharacteristicModel characteristic) {
    if (isNameExists(characteristic.name)) {
      return false;
    }
    _characteristics.add(characteristic);
    onPersist?.call(characteristics);
    notifyListeners();
    return true;
  }

  bool updateCharacteristic(RiceCharacteristicModel characteristic) {
    final index =
        _characteristics.indexWhere((item) => item.id == characteristic.id);
    if (index == -1 ||
        isNameExists(characteristic.name, excludeId: characteristic.id)) {
      return false;
    }

    _characteristics[index] = characteristic;
    onPersist?.call(characteristics);
    notifyListeners();
    return true;
  }

  bool deleteCharacteristic(String id, {void Function(String id)? onDeleted}) {
    final index = _characteristics.indexWhere((item) => item.id == id);
    if (index == -1) {
      return false;
    }

    _characteristics.removeAt(index);
    onDeleted?.call(id);
    onPersist?.call(characteristics);
    notifyListeners();
    return true;
  }

  List<RiceCharacteristicModel> getCharacteristicsForIds(List<String> ids) {
    if (ids.isEmpty) return const [];
    final idSet = ids.toSet();
    return _characteristics
        .where((c) => idSet.contains(c.id))
        .toList(growable: false);
  }
}
