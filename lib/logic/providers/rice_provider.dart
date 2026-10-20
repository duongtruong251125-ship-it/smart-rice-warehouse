import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

class RiceProvider extends ChangeNotifier {
  RiceProvider({
    List<RiceModel>? initial,
    this.onPersist,
    this.repository,
  }) : _rices = List<RiceModel>.from(
          initial ?? DefaultDataRegistry.provider?.rices ?? const [],
        ) {
    for (final rice in _rices) {
      if (rice.imagePath?.isNotEmpty == true) {
        _localImagePaths[rice.id] = rice.imagePath!;
      }
    }
    if (repository != null) _subscribeToFirestore();
  }

  final List<RiceModel> _rices;
  final Map<String, String> _localImagePaths = {};
  final ValueChanged<List<RiceModel>>? onPersist;
  final CrudRepository<RiceModel>? repository;
  StreamSubscription<List<RiceModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<RiceModel> get rices => List<RiceModel>.unmodifiable(_rices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  static String? resolveDefaultAssetImage(RiceModel rice) {
    if (rice.imagePath?.trim().isNotEmpty == true) {
      return rice.imagePath;
    }
    final key =
        '${rice.id} ${rice.code} ${rice.name} ${rice.category}'.toLowerCase();
    if (key.contains('st25') || key.contains('st24')) {
      return 'assets/images/rice/st25.jpg';
    }
    if (key.contains('jasmine') || key.contains('lài') || key.contains('lai')) {
      return 'assets/images/rice/jasmine.jpg';
    }
    if (key.contains('brown') ||
        key.contains('lut') ||
        key.contains('lứt') ||
        key.contains('dinh dưỡng')) {
      return 'assets/images/rice/brown-rice.jpg';
    }
    if (key.contains('nang-huong') ||
        key.contains('nàng hương') ||
        key.contains('tai-nguyen') ||
        key.contains('tài nguyên') ||
        key.contains('đặc sản')) {
      return 'assets/images/rice/nang-huong.jpg';
    }
    if (key.contains('glutinous') ||
        key.contains('nep') ||
        key.contains('nếp')) {
      return 'assets/images/rice/glutinous-rice.jpg';
    }
    return null;
  }

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteRices) {
        _rices
          ..clear()
          ..addAll(
            remoteRices.map(
              (rice) => rice.copyWith(
                imagePath:
                    _localImagePaths[rice.id] ?? resolveDefaultAssetImage(rice),
              ),
            ),
          );
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(rices);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ danh mục gạo: $error';
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

  RiceModel? findById(String id) {
    for (final rice in _rices) {
      if (rice.id == id) return rice;
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

  Future<bool> addRiceOnline(RiceModel rice) async {
    if (repository == null) return addRice(rice);
    if (isCodeExists(rice.code)) return false;
    if (rice.imagePath?.isNotEmpty == true) {
      _localImagePaths[rice.id] = rice.imagePath!;
    }
    try {
      await repository!.create(rice.id, rice);
      _errorMessage = null;
      return true;
    } catch (error) {
      _localImagePaths.remove(rice.id);
      _errorMessage = 'Không thể thêm loại gạo: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRiceOnline(RiceModel rice) async {
    if (repository == null) return updateRice(rice);
    if (findById(rice.id) == null ||
        isCodeExists(rice.code, excludeId: rice.id)) {
      return false;
    }
    final previousPath = _localImagePaths[rice.id];
    if (rice.imagePath?.isNotEmpty == true) {
      _localImagePaths[rice.id] = rice.imagePath!;
    } else {
      _localImagePaths.remove(rice.id);
    }
    try {
      await repository!.update(rice.id, rice);
      _errorMessage = null;
      return true;
    } catch (error) {
      if (previousPath == null) {
        _localImagePaths.remove(rice.id);
      } else {
        _localImagePaths[rice.id] = previousPath;
      }
      _errorMessage = 'Không thể cập nhật loại gạo: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRiceOnline(
    String id, {
    bool Function(String id)? isReferenced,
  }) async {
    if (repository == null) return deleteRice(id, isReferenced: isReferenced);
    if (isReferenced?.call(id) ?? false) return false;
    final rice = findById(id);
    if (rice == null) return false;
    try {
      await repository!.delete(id);
      _localImagePaths.remove(id);
      await MediaService.delete(rice.imagePath);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể xóa loại gạo: $error';
      notifyListeners();
      return false;
    }
  }

  /// Local compatibility API used while tests and remaining modules are being
  /// migrated. Cloud screens use the asynchronous methods above.
  bool addRice(RiceModel rice) {
    if (repository != null || isCodeExists(rice.code)) return false;
    _rices.add(rice);
    onPersist?.call(rices);
    notifyListeners();
    return true;
  }

  bool updateRice(RiceModel rice) {
    if (repository != null) return false;
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
    if (repository != null || (isReferenced?.call(id) ?? false)) return false;
    final index = _rices.indexWhere((rice) => rice.id == id);
    if (index == -1) return false;
    final removedRice = _rices.removeAt(index);
    unawaited(MediaService.delete(removedRice.imagePath));
    onPersist?.call(rices);
    notifyListeners();
    return true;
  }

  List<RiceModel> searchRice(String query) => filterRices(query: query);

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
              .where((item) => rice.characteristicIds.contains(item.id))
              .any((item) => item.name.toLowerCase().contains(normalizedQuery));
      if (!matchesQuery) return false;
      return selectedCharacteristicIds.isEmpty ||
          selectedCharacteristicIds
              .every((id) => rice.characteristicIds.contains(id));
    }).toList(growable: false);
  }

  Future<bool> removeCharacteristicFromAllOnline(
      String characteristicId) async {
    if (repository == null) {
      removeCharacteristicFromAll(characteristicId);
      return true;
    }
    final affected = _rices
        .where((rice) => rice.characteristicIds.contains(characteristicId))
        .toList(growable: false);
    try {
      for (final rice in affected) {
        final ids = List<String>.from(rice.characteristicIds)
          ..remove(characteristicId);
        await repository!.update(
          rice.id,
          rice.copyWith(characteristicIds: ids),
        );
      }
      return true;
    } catch (error) {
      _errorMessage = 'Không thể gỡ đặc tính khỏi sản phẩm: $error';
      notifyListeners();
      return false;
    }
  }

  void removeCharacteristicFromAll(String characteristicId) {
    if (repository != null) return;
    var changed = false;
    for (var index = 0; index < _rices.length; index++) {
      if (_rices[index].characteristicIds.contains(characteristicId)) {
        final updatedIds = List<String>.from(_rices[index].characteristicIds)
          ..remove(characteristicId);
        _rices[index] = _rices[index].copyWith(characteristicIds: updatedIds);
        changed = true;
      }
    }
    if (changed) {
      onPersist?.call(rices);
      notifyListeners();
    }
  }

  int countRicesWithCharacteristic(String characteristicId) => _rices
      .where((rice) => rice.characteristicIds.contains(characteristicId))
      .length;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
