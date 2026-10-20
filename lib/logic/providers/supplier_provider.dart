import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';

class SupplierProvider extends ChangeNotifier {
  SupplierProvider({
    List<SupplierModel>? initial,
    this.onPersist,
    this.repository,
  }) : _suppliers = List<SupplierModel>.from(
          initial ?? DefaultDataRegistry.provider?.suppliers ?? const [],
        ) {
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  final List<SupplierModel> _suppliers;
  final ValueChanged<List<SupplierModel>>? onPersist;
  final CrudRepository<SupplierModel>? repository;
  StreamSubscription<List<SupplierModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<SupplierModel> get suppliers =>
      List<SupplierModel>.unmodifiable(_suppliers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteSuppliers) {
        _suppliers
          ..clear()
          ..addAll(remoteSuppliers);
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(suppliers);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ nhà cung cấp: $error';
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

  SupplierModel? findById(String id) {
    for (final supplier in _suppliers) {
      if (supplier.id == id) {
        return supplier;
      }
    }
    return null;
  }

  Future<bool> addSupplierOnline(SupplierModel supplier) async {
    if (repository == null) {
      addSupplier(supplier);
      return true;
    }
    try {
      await repository!.create(supplier.id, supplier);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể thêm nhà cung cấp: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplierOnline(SupplierModel supplier) async {
    if (repository == null) {
      return updateSupplier(supplier);
    }
    try {
      await repository!.update(supplier.id, supplier);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể cập nhật nhà cung cấp: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSupplierOnline(
    String id, {
    bool Function(String id)? isReferenced,
  }) async {
    if (repository == null) {
      return deleteSupplier(id, isReferenced: isReferenced);
    }
    if (isReferenced?.call(id) ?? false) return false;
    try {
      await repository!.delete(id);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể xóa nhà cung cấp: $error';
      notifyListeners();
      return false;
    }
  }

  void addSupplier(SupplierModel supplier) {
    if (repository != null) {
      unawaited(addSupplierOnline(supplier));
      return;
    }
    _suppliers.add(supplier);
    onPersist?.call(suppliers);
    notifyListeners();
  }

  bool updateSupplier(SupplierModel supplier) {
    if (repository != null) {
      unawaited(updateSupplierOnline(supplier));
      return true;
    }
    final index = _suppliers.indexWhere((item) => item.id == supplier.id);
    if (index == -1) {
      return false;
    }

    _suppliers[index] = supplier;
    onPersist?.call(suppliers);
    notifyListeners();
    return true;
  }

  bool deleteSupplier(String id, {bool Function(String id)? isReferenced}) {
    if (isReferenced?.call(id) ?? false) return false;
    if (repository != null) {
      unawaited(deleteSupplierOnline(id, isReferenced: isReferenced));
      return true;
    }
    final previousLength = _suppliers.length;
    _suppliers.removeWhere((supplier) => supplier.id == id);
    if (_suppliers.length == previousLength) {
      return false;
    }

    onPersist?.call(suppliers);
    notifyListeners();
    return true;
  }

  List<SupplierModel> searchSuppliers(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return suppliers;
    }

    return _suppliers
        .where(
          (supplier) =>
              supplier.name.toLowerCase().contains(normalizedQuery) ||
              supplier.phone.contains(normalizedQuery) ||
              supplier.email.toLowerCase().contains(normalizedQuery) ||
              supplier.address.toLowerCase().contains(normalizedQuery) ||
              supplier.taxCode.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
