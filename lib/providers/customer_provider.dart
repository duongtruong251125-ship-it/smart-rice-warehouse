import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';

class CustomerProvider extends ChangeNotifier {
  CustomerProvider()
      : _customers = List<CustomerModel>.from(MockData.customers);

  final List<CustomerModel> _customers;

  List<CustomerModel> get customers =>
      List<CustomerModel>.unmodifiable(_customers);

  CustomerModel? findById(String id) {
    for (final customer in _customers) {
      if (customer.id == id) {
        return customer;
      }
    }
    return null;
  }

  void addCustomer(CustomerModel customer) {
    _customers.add(customer);
    notifyListeners();
  }

  bool updateCustomer(CustomerModel customer) {
    final index = _customers.indexWhere((item) => item.id == customer.id);
    if (index == -1) {
      return false;
    }

    _customers[index] = customer;
    notifyListeners();
    return true;
  }

  bool deleteCustomer(String id) {
    final previousLength = _customers.length;
    _customers.removeWhere((customer) => customer.id == id);
    if (_customers.length == previousLength) {
      return false;
    }

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
              customer.customerType.label
                  .toLowerCase()
                  .contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
