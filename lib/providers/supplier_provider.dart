import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';

class SupplierProvider extends ChangeNotifier {
  SupplierProvider()
      : _suppliers = List<SupplierModel>.from(MockData.suppliers);

  final List<SupplierModel> _suppliers;

  List<SupplierModel> get suppliers =>
      List<SupplierModel>.unmodifiable(_suppliers);

  SupplierModel? findById(String id) {
    for (final supplier in _suppliers) {
      if (supplier.id == id) {
        return supplier;
      }
    }
    return null;
  }

  void addSupplier(SupplierModel supplier) {
    _suppliers.add(supplier);
    notifyListeners();
  }

  bool updateSupplier(SupplierModel supplier) {
    final index = _suppliers.indexWhere((item) => item.id == supplier.id);
    if (index == -1) {
      return false;
    }

    _suppliers[index] = supplier;
    notifyListeners();
    return true;
  }

  bool deleteSupplier(String id) {
    final previousLength = _suppliers.length;
    _suppliers.removeWhere((supplier) => supplier.id == id);
    if (_suppliers.length == previousLength) {
      return false;
    }

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
              supplier.taxCode.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
