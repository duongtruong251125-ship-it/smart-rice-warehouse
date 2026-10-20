import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/services/damage_form_service.dart';

/// ViewModel for managing Damage Report Form state, batch selection, and submission.
class DamageFormViewModel extends ChangeNotifier {
  DamageFormViewModel({
    DamageFormService? service,
    BatchModel? initialBatch,
  })  : _service = service ?? DamageFormService(),
        _selectedBatch = initialBatch;

  final DamageFormService _service;

  BatchModel? _selectedBatch;
  DamageReason _selectedReason = DamageReason.baoRach;
  String? _selectedImagePath;
  bool _isSubmitting = false;
  String? _lastError;

  BatchModel? get selectedBatch => _selectedBatch;
  DamageReason get selectedReason => _selectedReason;
  String? get selectedImagePath => _selectedImagePath;
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

  void setSelectedBatch(BatchModel? batch) {
    if (_selectedBatch == batch) return;
    _selectedBatch = batch;
    notifyListeners();
  }

  void setSelectedReason(DamageReason reason) {
    if (_selectedReason == reason) return;
    _selectedReason = reason;
    notifyListeners();
  }

  void setSelectedImagePath(String? path) {
    if (_selectedImagePath == path) return;
    _selectedImagePath = path;
    notifyListeners();
  }

  List<BatchModel> getAvailableBatches(BatchProvider batchProvider) {
    return batchProvider.batches
        .where((b) => b.quantity > 0 && b.status != BatchStatus.expired)
        .toList(growable: false);
  }

  Future<({bool success, String? message, double? quantity})> submit({
    required BatchProvider batchProvider,
    required DamageProvider damageProvider,
    required String quantityText,
    required String note,
    String createdBy = 'Admin',
  }) async {
    if (_isSubmitting) {
      return (
        success: false,
        message: 'Đang xử lý yêu cầu báo hỏng trước đó, vui lòng đợi...',
        quantity: null,
      );
    }
    if (_selectedBatch == null) {
      return (
        success: false,
        message: 'Vui lòng chọn lô gạo cần báo hỏng.',
        quantity: null,
      );
    }

    _isSubmitting = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _service.submit(
        batch: _selectedBatch!,
        batches: batchProvider,
        damages: damageProvider,
        quantityText: quantityText,
        reason: _selectedReason,
        note: note,
        imagePath: _selectedImagePath,
        createdBy: createdBy,
      );

      _isSubmitting = false;
      _lastError = result.success ? null : result.message;
      notifyListeners();
      return result;
    } catch (e) {
      _isSubmitting = false;
      _lastError = 'Lỗi ghi nhận báo hỏng: $e';
      notifyListeners();
      return (
        success: false,
        message: _lastError,
        quantity: null,
      );
    }
  }
}
