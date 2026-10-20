import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/services/fefo_service.dart';
import 'package:smart_rice_warehouse/logic/services/inventory_form_service.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';

/// ViewModel for managing Export Form state, FEFO preview, unit conversions, validation and submission.
class ExportFormViewModel extends ChangeNotifier {
  ExportFormViewModel({
    InventoryFormService? inventoryFormService,
  }) : _inventoryFormService = inventoryFormService ?? InventoryFormService();

  final InventoryFormService _inventoryFormService;

  static const List<String> unitLabels = [
    'Kg',
    'Bao (50kg)',
    'Tạ (100kg)',
    'Tấn'
  ];

  CustomerModel? _selectedCustomer;
  RiceModel? _selectedRice;
  int _selectedUnitIndex = 0;

  FefoAllocationResult? _currentFefoResult;
  double _lastCalculatedQuantityKg = 0;
  double _lastCalculatedSellingPrice = 0;
  bool _isSubmitting = false;
  String? _lastError;

  CustomerModel? get selectedCustomer => _selectedCustomer;
  RiceModel? get selectedRice => _selectedRice;
  int get selectedUnitIndex => _selectedUnitIndex;
  FefoAllocationResult? get currentFefoResult => _currentFefoResult;
  double get lastCalculatedQuantityKg => _lastCalculatedQuantityKg;
  double get lastCalculatedSellingPrice => _lastCalculatedSellingPrice;
  bool get isSubmitting => _isSubmitting;
  String? get lastError => _lastError;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void setSubmittingForTesting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void setCustomer(CustomerModel? customer) {
    if (_selectedCustomer == customer) return;
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setRice(RiceModel? rice) {
    if (_selectedRice == rice) return;
    _selectedRice = rice;
    notifyListeners();
  }

  void setUnitIndex(int index) {
    if (_selectedUnitIndex == index) return;
    _selectedUnitIndex = index;
    notifyListeners();
  }

  double calculateQuantityKg(String quantityText) {
    final input = FormValidators.parseNumber(quantityText) ?? 0.0;
    return InventoryFormService.quantityInKg(input, _selectedUnitIndex);
  }

  double calculateTotalAmount(String quantityText, String sellingPriceText) {
    final qtyKg = calculateQuantityKg(quantityText);
    final pricePerKg = FormValidators.parseNumber(sellingPriceText) ?? 0;
    return InventoryFormService.totalAmount(qtyKg, pricePerKg);
  }

  String? validateCustomer(CustomerModel? value) {
    return value == null ? 'Vui lòng chọn khách hàng' : null;
  }

  String? validateRice(RiceModel? value) {
    return value == null ? 'Vui lòng chọn loại gạo' : null;
  }

  String? validateQuantity(String? value, BatchProvider batchProvider) {
    final error = FormValidators.number(value, 'Số lượng', positive: true);
    if (error != null) return error;

    final rice = _selectedRice;
    if (rice != null) {
      final currentStock = batchProvider.totalStockForRice(rice.id);
      final reqKg = calculateQuantityKg(value ?? '');
      if (reqKg > currentStock) {
        return 'Vượt quá tồn kho khả dụng (${NumberFormatter.quantity(currentStock)} ${rice.unit})';
      }
    }
    return null;
  }

  String? validateSellingPrice(String? value) {
    return FormValidators.number(value, 'Giá bán');
  }

  ({bool success, String? error, FefoAllocationResult? result}) previewFefo({
    required ExportProvider exportProvider,
    required BatchProvider batchProvider,
    required String quantityText,
    required String sellingPriceText,
  }) {
    if (_selectedCustomer == null) {
      return (success: false, error: 'Vui lòng chọn khách hàng', result: null);
    }
    if (_selectedRice == null) {
      return (success: false, error: 'Vui lòng chọn loại gạo', result: null);
    }

    final quantityKg = calculateQuantityKg(quantityText);
    if (quantityKg <= 0) {
      return (success: false, error: 'Số lượng phải lớn hơn 0', result: null);
    }

    final sellingPrice = FormValidators.parseNumber(sellingPriceText);
    if (sellingPrice == null || sellingPrice < 0) {
      return (success: false, error: 'Giá bán không hợp lệ', result: null);
    }

    final rice = _selectedRice!;
    final fefoResult = exportProvider.previewFefoAllocation(
      riceId: rice.id,
      quantity: quantityKg,
    );

    if (!fefoResult.isSuccess) {
      return (
        success: false,
        error: fefoResult.errorMessage ?? 'Không đủ tồn kho khả dụng để xuất.',
        result: null,
      );
    }

    _currentFefoResult = fefoResult;
    _lastCalculatedQuantityKg = quantityKg;
    _lastCalculatedSellingPrice = sellingPrice;
    _lastError = null;
    notifyListeners();

    return (success: true, error: null, result: fefoResult);
  }

  Future<({bool success, String? message})> confirmExport({
    required ExportProvider exportProvider,
    String note = '',
  }) async {
    if (_isSubmitting) {
      return (
        success: false,
        message: 'Đang xử lý yêu cầu xuất kho trước đó, vui lòng đợi...',
      );
    }
    if (_selectedCustomer == null ||
        _selectedRice == null ||
        _currentFefoResult == null) {
      return (success: false, message: 'Dữ liệu xuất kho không hợp lệ.');
    }

    _isSubmitting = true;
    _lastError = null;
    notifyListeners();

    try {
      final created = await _inventoryFormService.submitExport(
        provider: exportProvider,
        customer: _selectedCustomer!,
        rice: _selectedRice!,
        quantity: _lastCalculatedQuantityKg,
        sellingPrice: _lastCalculatedSellingPrice,
        note: note.trim(),
        allocations: _currentFefoResult!.allocations,
      );

      _isSubmitting = false;

      if (!created) {
        _lastError = exportProvider.errorMessage ??
            'Xuất kho thất bại: không đủ tồn kho khả dụng.';
        notifyListeners();
        return (
          success: false,
          message: _lastError,
        );
      }

      _lastError = null;
      notifyListeners();
      return (success: true, message: 'Xuất kho thành công theo quy tắc FEFO');
    } catch (e) {
      _isSubmitting = false;
      _lastError = 'Lỗi xuất kho: $e';
      notifyListeners();
      return (success: false, message: _lastError);
    }
  }
}
