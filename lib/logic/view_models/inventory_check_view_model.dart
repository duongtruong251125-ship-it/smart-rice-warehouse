import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';

/// ViewModel for managing an Inventory Check session, recording item counts, and completing adjustments.
class InventoryCheckViewModel extends ChangeNotifier {
  void ensureActiveSession({
    required InventoryCheckProvider checkProvider,
    String createdBy = 'Admin',
  }) {
    if (!checkProvider.hasActiveSession) {
      checkProvider.startNewSession(createdBy: createdBy);
      notifyListeners();
    }
  }

  ({bool success, String? error, double difference}) saveItemCount({
    required InventoryCheckProvider checkProvider,
    required BatchModel batch,
    required String actualQuantityText,
    required InventoryCheckReason reason,
    String note = '',
  }) {
    final actual = FormValidators.parseNumber(actualQuantityText);
    if (actual == null || actual < 0) {
      return (
        success: false,
        error: 'Số lượng thực tế phải là số không âm.',
        difference: 0.0,
      );
    }

    final diff = actual - batch.quantity;
    checkProvider.addOrUpdateItem(
      batch: batch,
      actualQuantity: actual,
      reason: reason,
      note: note.trim(),
    );

    notifyListeners();
    return (success: true, error: null, difference: diff);
  }

  Future<
      ({
        bool success,
        String message,
        int itemCount,
        double totalDifference
      })> completeSession({
    required InventoryCheckProvider checkProvider,
    required BatchProvider batchProvider,
  }) async {
    final session = checkProvider.activeSession;
    if (session == null || session.items.isEmpty) {
      return (
        success: false,
        message: 'Không có dữ liệu kiểm kê để cập nhật.',
        itemCount: 0,
        totalDifference: 0.0,
      );
    }

    final itemCount = session.items.length;
    final totalDiff = session.totalDifference;

    final ok =
        await checkProvider.completeSession(batchProvider: batchProvider);
    notifyListeners();

    if (ok) {
      return (
        success: true,
        message: 'Đã hoàn tất kiểm kê và cập nhật tồn kho.',
        itemCount: itemCount,
        totalDifference: totalDiff,
      );
    } else {
      return (
        success: false,
        message: checkProvider.errorMessage ??
            'Không thể hoàn tất kiểm kê. Kiểm tra lại các lô đã chọn.',
        itemCount: itemCount,
        totalDifference: totalDiff,
      );
    }
  }
}
