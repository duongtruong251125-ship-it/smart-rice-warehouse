import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/services/inventory_form_service.dart';
import 'package:smart_rice_warehouse/logic/services/ocr_service.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';

/// ViewModel for OCR Invoice scanning, extraction, review state, validation and receipt creation.
class OcrInvoiceViewModel extends ChangeNotifier {
  OcrInvoiceViewModel({
    OcrService? ocrService,
    InventoryFormService? inventoryFormService,
    DateTime Function()? clock,
  })  : _ocrService = ocrService ?? const OcrService(),
        _inventoryFormService = inventoryFormService ?? InventoryFormService(),
        _clock = clock ?? DateTime.now;

  final OcrService _ocrService;
  final InventoryFormService _inventoryFormService;
  final DateTime Function() _clock;

  bool _isScanning = false;
  String _rawOcrText = '';
  SupplierModel? _selectedSupplier;
  RiceModel? _selectedRice;
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  String _suggestedQuantityText = '';
  String _suggestedPurchasePriceText = '';
  String _suggestedBatchCode = '';
  bool _isSubmitting = false;

  bool get isScanning => _isScanning;
  String get rawOcrText => _rawOcrText;
  SupplierModel? get selectedSupplier => _selectedSupplier;
  RiceModel? get selectedRice => _selectedRice;
  DateTime? get manufactureDate => _manufactureDate;
  DateTime? get expiryDate => _expiryDate;
  String get suggestedQuantityText => _suggestedQuantityText;
  String get suggestedPurchasePriceText => _suggestedPurchasePriceText;
  String get suggestedBatchCode => _suggestedBatchCode;
  bool get isSubmitting => _isSubmitting;

  void setSupplier(SupplierModel? supplier) {
    if (_selectedSupplier == supplier) return;
    _selectedSupplier = supplier;
    notifyListeners();
  }

  void setRice(RiceModel? rice) {
    if (_selectedRice == rice) return;
    _selectedRice = rice;
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

  Future<({bool success, String? error, String? recognizedText})> processImage({
    required String imagePath,
    required List<SupplierModel> suppliers,
    required List<RiceModel> rices,
  }) async {
    _isScanning = true;
    notifyListeners();

    try {
      final text = await _ocrService.recognizeTextFromImage(imagePath);
      if (text.isEmpty) {
        _isScanning = false;
        notifyListeners();
        return (
          success: false,
          error: 'Không nhận diện được chữ trong ảnh.',
          recognizedText: null,
        );
      }

      _rawOcrText = text;
      parseAndExtract(
        rawText: text,
        suppliers: suppliers,
        rices: rices,
      );

      _isScanning = false;
      notifyListeners();
      return (success: true, error: null, recognizedText: text);
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      return (
        success: false,
        error: 'Không thể đọc ảnh: $e',
        recognizedText: null
      );
    }
  }

  void parseAndExtract({
    required String rawText,
    required List<SupplierModel> suppliers,
    required List<RiceModel> rices,
  }) {
    _rawOcrText = rawText;
    final result = _ocrService.parseInvoice(
      rawText: rawText,
      suppliers: suppliers,
      rices: rices,
    );

    _suggestedQuantityText = result.quantity != null
        ? (result.quantity == result.quantity!.roundToDouble()
            ? result.quantity!.toInt().toString()
            : result.quantity!.toString())
        : '';

    _suggestedPurchasePriceText = result.purchasePrice != null
        ? (result.purchasePrice == result.purchasePrice!.roundToDouble()
            ? result.purchasePrice!.toInt().toString()
            : result.purchasePrice!.toString())
        : '';

    final now = _clock();
    _suggestedBatchCode = result.batchCode ??
        'LO-${now.millisecondsSinceEpoch.toString().substring(7)}';

    if (result.matchedSupplierId != null) {
      _selectedSupplier = suppliers.cast<SupplierModel?>().firstWhere(
            (s) => s?.id == result.matchedSupplierId,
            orElse: () => null,
          );
    }

    if (result.matchedRiceId != null) {
      _selectedRice = rices.cast<RiceModel?>().firstWhere(
            (r) => r?.id == result.matchedRiceId,
            orElse: () => null,
          );
    }

    _manufactureDate =
        result.manufactureDate ?? now.subtract(const Duration(days: 7));
    _expiryDate = result.expiryDate ?? now.add(const Duration(days: 365));

    notifyListeners();
  }

  Future<({bool success, String? message, String? receiptCode})> submit({
    required ImportProvider importProvider,
    required String quantityText,
    required String priceText,
    required String batchCodeText,
  }) async {
    if (_selectedSupplier == null) {
      return (
        success: false,
        message: 'Vui lòng chọn hoặc xác nhận nhà cung cấp.',
        receiptCode: null,
      );
    }
    if (_selectedRice == null) {
      return (
        success: false,
        message: 'Vui lòng chọn hoặc xác nhận loại gạo.',
        receiptCode: null,
      );
    }

    final quantity = FormValidators.parseNumber(quantityText);
    if (quantity == null || quantity <= 0) {
      return (
        success: false,
        message: 'Số lượng phải lớn hơn 0.',
        receiptCode: null,
      );
    }

    final price = FormValidators.parseNumber(priceText);
    if (price == null || price <= 0) {
      return (
        success: false,
        message: 'Giá nhập phải lớn hơn 0.',
        receiptCode: null,
      );
    }

    final batchCode = batchCodeText.trim();
    if (batchCode.isEmpty) {
      return (
        success: false,
        message: 'Mã lô không được để trống.',
        receiptCode: null,
      );
    }

    final now = _clock();
    _isSubmitting = true;
    notifyListeners();

    try {
      final receiptCode = importProvider.generateReceiptCode();
      final success = await _inventoryFormService.submitImport(
        provider: importProvider,
        supplier: _selectedSupplier!,
        rice: _selectedRice!,
        quantity: quantity,
        purchasePrice: price,
        batchCode: batchCode,
        manufactureDate: _manufactureDate ?? now,
        expiryDate: _expiryDate ?? now.add(const Duration(days: 365)),
      );

      _isSubmitting = false;
      notifyListeners();

      if (success) {
        return (
          success: true,
          message: 'Đã tạo phiếu nhập $receiptCode từ OCR thành công!',
          receiptCode: receiptCode,
        );
      } else {
        return (
          success: false,
          message: importProvider.errorMessage ??
              'Không thể tạo phiếu nhập từ dữ liệu OCR.',
          receiptCode: null,
        );
      }
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return (
        success: false,
        message: 'Lỗi tạo phiếu nhập OCR: $e',
        receiptCode: null,
      );
    }
  }
}
