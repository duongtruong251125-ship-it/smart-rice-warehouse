import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/services/inventory_form_service.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';

/// ViewModel for managing Import Form state, selection, validation and submission.
class ImportFormViewModel extends ChangeNotifier {
  ImportFormViewModel({
    InventoryFormService? inventoryFormService,
    DateTime Function()? clock,
  })  : _inventoryFormService = inventoryFormService ?? InventoryFormService(),
        _clock = clock ?? DateTime.now;

  final InventoryFormService _inventoryFormService;
  final DateTime Function() _clock;

  static const String newBatchOption = '__NEW_BATCH__';

  SupplierModel? _selectedSupplier;
  RiceModel? _selectedRice;
  String _selectedBatchCode = newBatchOption;
  BatchModel? _selectedExistingBatch;
  String _suggestedBatchCode = '';
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  bool _isSubmitting = false;
  String? _lastError;

  SupplierModel? get selectedSupplier => _selectedSupplier;
  RiceModel? get selectedRice => _selectedRice;
  String get selectedBatchCode => _selectedBatchCode;
  BatchModel? get selectedExistingBatch => _selectedExistingBatch;
  String get suggestedBatchCode => _suggestedBatchCode;
  DateTime? get manufactureDate => _manufactureDate;
  DateTime? get expiryDate => _expiryDate;
  bool get isSubmitting => _isSubmitting;
  String? get lastError => _lastError;

  bool get isCreatingNewBatch => _selectedBatchCode == newBatchOption;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void setSubmittingForTesting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void setSupplier(SupplierModel? supplier) {
    if (_selectedSupplier == supplier) return;
    _selectedSupplier = supplier;
    notifyListeners();
  }

  void setRice(RiceModel? rice, List<BatchModel> allBatches) {
    _selectedRice = rice;
    if (rice != null) {
      final existingBatches =
          allBatches.where((b) => b.riceId == rice.id).toList();
      if (existingBatches.isNotEmpty) {
        selectBatch(existingBatches.first);
      } else {
        selectNewBatchMode(rice: rice, allBatches: allBatches);
      }
    } else {
      notifyListeners();
    }
  }

  void selectBatch(BatchModel batch) {
    _selectedBatchCode = batch.code;
    _selectedExistingBatch = batch;
    _manufactureDate = batch.manufactureDate;
    _expiryDate = batch.expiryDate;
    notifyListeners();
  }

  void selectNewBatchMode({
    RiceModel? rice,
    required List<BatchModel> allBatches,
  }) {
    final targetRice = rice ?? _selectedRice;
    _selectedBatchCode = newBatchOption;
    _selectedExistingBatch = null;
    _suggestedBatchCode = generateBatchCodeSuggestion(targetRice, allBatches);

    final now = _clock();
    _manufactureDate ??= now;
    _expiryDate ??= now.add(const Duration(days: 365));
    notifyListeners();
  }

  void setManufactureDate(DateTime date) {
    _manufactureDate = date;
    notifyListeners();
  }

  void setExpiryDate(DateTime date) {
    _expiryDate = date;
    notifyListeners();
  }

  static String generateBatchCodeSuggestion(
    RiceModel? rice,
    List<BatchModel> allBatches,
  ) {
    final prefix = rice?.code ?? 'LO';
    final batches = rice == null
        ? allBatches
        : allBatches.where((b) => b.riceId == rice.id).toList();
    return 'LO-$prefix-${(batches.length + 1).toString().padLeft(3, '0')}';
  }

  String? validateSupplier(SupplierModel? value) {
    return value == null ? 'Vui lòng chọn nhà cung cấp' : null;
  }

  String? validateRice(RiceModel? value) {
    return value == null ? 'Vui lòng chọn loại gạo' : null;
  }

  String? validatePositiveNumber(String? value, String fieldName) {
    return FormValidators.number(value, fieldName, positive: true);
  }

  String? validateNonNegativeNumber(String? value, String fieldName) {
    return FormValidators.number(value, fieldName);
  }

  String? validateBatchCode(String? value, BatchProvider batchProvider) {
    if (!isCreatingNewBatch) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã lô mới';
    }
    if (batchProvider.isBatchCodeExists(value.trim())) {
      return 'Mã lô "${value.trim()}" đã tồn tại. Vui lòng chọn lô từ danh sách hoặc nhập mã khác.';
    }
    return null;
  }

  String? validateManufactureDate() {
    return _manufactureDate == null ? 'Vui lòng chọn ngày sản xuất' : null;
  }

  String? validateExpiryDate() {
    if (_expiryDate == null) {
      return 'Vui lòng chọn hạn sử dụng';
    }
    if (_manufactureDate != null && !_expiryDate!.isAfter(_manufactureDate!)) {
      return 'Hạn sử dụng phải sau ngày sản xuất';
    }
    return null;
  }

  double calculateTotalAmount(String quantityText, String purchasePriceText) {
    final quantity = FormValidators.parseNumber(quantityText) ?? 0;
    final price = FormValidators.parseNumber(purchasePriceText) ?? 0;
    return InventoryFormService.totalAmount(quantity, price);
  }

  Future<({bool success, String? message})> submitImport({
    required ImportProvider importProvider,
    required String quantityText,
    required String purchasePriceText,
    required String batchCodeInput,
  }) async {
    if (_isSubmitting) {
      return (
        success: false,
        message: 'Đang xử lý yêu cầu trước đó, vui lòng đợi...',
      );
    }
    if (_selectedSupplier == null) {
      return (success: false, message: 'Vui lòng chọn nhà cung cấp');
    }
    if (_selectedRice == null) {
      return (success: false, message: 'Vui lòng chọn loại gạo');
    }

    final quantity = FormValidators.parseNumber(quantityText);
    if (quantity == null || quantity <= 0) {
      return (success: false, message: 'Số lượng phải lớn hơn 0');
    }

    final price = FormValidators.parseNumber(purchasePriceText);
    if (price == null || price < 0) {
      return (success: false, message: 'Giá nhập không hợp lệ');
    }

    final dateError = validateExpiryDate();
    if (dateError != null) {
      return (success: false, message: dateError);
    }
    if (_manufactureDate == null || _expiryDate == null) {
      return (
        success: false,
        message: 'Vui lòng chọn ngày sản xuất và hạn sử dụng'
      );
    }

    final batchCode =
        isCreatingNewBatch ? batchCodeInput.trim() : _selectedBatchCode;

    if (batchCode.isEmpty) {
      return (success: false, message: 'Mã lô không được để trống');
    }

    _isSubmitting = true;
    _lastError = null;
    notifyListeners();

    try {
      final created = await _inventoryFormService.submitImport(
        provider: importProvider,
        supplier: _selectedSupplier!,
        rice: _selectedRice!,
        quantity: quantity,
        purchasePrice: price,
        batchCode: batchCode,
        manufactureDate: _manufactureDate!,
        expiryDate: _expiryDate!,
        existingBatchId: isCreatingNewBatch ? null : _selectedExistingBatch?.id,
      );

      _isSubmitting = false;

      if (!created) {
        _lastError = importProvider.errorMessage ??
            'Không thể tạo phiếu nhập cho mã lô này';
        notifyListeners();
        return (
          success: false,
          message: _lastError,
        );
      }

      _lastError = null;
      notifyListeners();
      return (success: true, message: 'Nhập kho thành công');
    } catch (e) {
      _isSubmitting = false;
      _lastError = 'Lỗi tạo phiếu nhập: $e';
      notifyListeners();
      return (success: false, message: _lastError);
    }
  }
}
