import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';

class RiceCharacteristicProvider extends ChangeNotifier {
  RiceCharacteristicProvider({
    List<RiceCharacteristicModel>? initial,
    this.onPersist,
    this.repository,
  }) : _characteristics = List<RiceCharacteristicModel>.from(
          initial ??
              DefaultDataRegistry.provider?.riceCharacteristics ??
              const [],
        ) {
    if (repository != null) _subscribeToFirestore();
  }

  final List<RiceCharacteristicModel> _characteristics;
  final ValueChanged<List<RiceCharacteristicModel>>? onPersist;
  final CrudRepository<RiceCharacteristicModel>? repository;
  StreamSubscription<List<RiceCharacteristicModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<RiceCharacteristicModel> get characteristics =>
      List<RiceCharacteristicModel>.unmodifiable(_characteristics);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (values) {
        _characteristics
          ..clear()
          ..addAll(values);
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(characteristics);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ đặc tính gạo: $error';
        notifyListeners();
      },
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void retrySync() {
    _errorMessage = null;
    if (repository != null) {
      _subscription?.cancel();
      _subscribeToFirestore();
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  RiceCharacteristicModel? findById(String id) {
    for (final item in _characteristics) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isNameExists(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    return _characteristics.any(
      (item) =>
          item.id != excludeId && item.name.trim().toLowerCase() == normalized,
    );
  }

  Future<bool> addCharacteristicOnline(
    RiceCharacteristicModel characteristic,
  ) async {
    if (repository == null) return addCharacteristic(characteristic);
    if (isNameExists(characteristic.name)) return false;
    try {
      await repository!.create(characteristic.id, characteristic);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể thêm đặc tính: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCharacteristicOnline(
    RiceCharacteristicModel characteristic,
  ) async {
    if (repository == null) return updateCharacteristic(characteristic);
    if (findById(characteristic.id) == null ||
        isNameExists(characteristic.name, excludeId: characteristic.id)) {
      return false;
    }
    try {
      await repository!.update(characteristic.id, characteristic);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể cập nhật đặc tính: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCharacteristicOnline(String id) async {
    if (repository == null) return deleteCharacteristic(id);
    if (findById(id) == null) return false;
    try {
      await repository!.delete(id);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể xóa đặc tính: $error';
      notifyListeners();
      return false;
    }
  }

  bool addCharacteristic(RiceCharacteristicModel characteristic) {
    if (repository != null || isNameExists(characteristic.name)) return false;
    _characteristics.add(characteristic);
    onPersist?.call(characteristics);
    notifyListeners();
    return true;
  }

  bool updateCharacteristic(RiceCharacteristicModel characteristic) {
    if (repository != null) return false;
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
    if (repository != null) return false;
    final index = _characteristics.indexWhere((item) => item.id == id);
    if (index == -1) return false;
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
        .where((item) => idSet.contains(item.id))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
