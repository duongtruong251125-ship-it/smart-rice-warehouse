import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/repositories/contracts/crud_repository.dart';

class CustomerProvider extends ChangeNotifier {
  CustomerProvider({
    List<CustomerModel>? initial,
    this.onPersist,
    this.repository,
  }) : _customers = List<CustomerModel>.from(initial ?? MockData.customers) {
    if (repository != null) {
      _subscribeToFirestore();
    }
  }

  final List<CustomerModel> _customers;
  final ValueChanged<List<CustomerModel>>? onPersist;
  final CrudRepository<CustomerModel>? repository;
  StreamSubscription<List<CustomerModel>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerModel> get customers =>
      List<CustomerModel>.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesFirestore => repository != null;

  void _subscribeToFirestore() {
    _isLoading = true;
    _subscription = repository!.watchAll().listen(
      (remoteCustomers) {
        _customers
          ..clear()
          ..addAll(remoteCustomers);
        _isLoading = false;
        _errorMessage = null;
        onPersist?.call(customers);
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Không thể đồng bộ khách hàng: $error';
        notifyListeners();
      },
    );
  }

  CustomerModel? findById(String id) {
    for (final customer in _customers) {
      if (customer.id == id) {
        return customer;
      }
    }
    return null;
  }

  Future<bool> addCustomerOnline(CustomerModel customer) async {
    if (repository == null) {
      addCustomer(customer);
      return true;
    }
    try {
      await repository!.create(customer.id, customer);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể thêm khách hàng: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCustomerOnline(CustomerModel customer) async {
    if (repository == null) {
      return updateCustomer(customer);
    }
    try {
      await repository!.update(customer.id, customer);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể cập nhật khách hàng: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomerOnline(
    String id, {
    bool Function(String id)? isReferenced,
  }) async {
    if (repository == null) {
      return deleteCustomer(id, isReferenced: isReferenced);
    }
    if (isReferenced?.call(id) ?? false) return false;
    try {
      await repository!.delete(id);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Không thể xóa khách hàng: $error';
      notifyListeners();
      return false;
    }
  }

  void addCustomer(CustomerModel customer) {
    if (repository != null) {
      unawaited(addCustomerOnline(customer));
      return;
    }
    _customers.add(customer);
    onPersist?.call(customers);
    notifyListeners();
  }

  bool updateCustomer(CustomerModel customer) {
    if (repository != null) {
      unawaited(updateCustomerOnline(customer));
      return true;
    }
    final index = _customers.indexWhere((item) => item.id == customer.id);
    if (index == -1) {
      return false;
    }

    _customers[index] = customer;
    onPersist?.call(customers);
    notifyListeners();
    return true;
  }

  bool deleteCustomer(String id, {bool Function(String id)? isReferenced}) {
    if (isReferenced?.call(id) ?? false) return false;
    if (repository != null) {
      unawaited(deleteCustomerOnline(id, isReferenced: isReferenced));
      return true;
    }
    final previousLength = _customers.length;
    _customers.removeWhere((customer) => customer.id == id);
    if (_customers.length == previousLength) {
      return false;
    }

    onPersist?.call(customers);
    notifyListeners();
    return true;
  }

  List<CustomerModel> searchCustomers(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return customers;
    }

    return _customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(normalizedQuery) ||
              customer.phone.contains(normalizedQuery) ||
              customer.address.toLowerCase().contains(normalizedQuery) ||
              customer.customerType.label
                  .toLowerCase()
                  .contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
