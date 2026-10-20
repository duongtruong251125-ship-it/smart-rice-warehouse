import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

class DamageFormService {
  Future<({bool success, String? message, double quantity})> submit({
    required BatchModel batch,
    required BatchProvider batches,
    required DamageProvider damages,
    required String quantityText,
    required DamageReason reason,
    required String note,
    String? imagePath,
    String createdBy = 'Admin',
  }) async {
    final quantity = double.tryParse(quantityText.trim().replaceAll(',', '.'));
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      return (
        success: false,
        message: 'Số lượng báo hỏng phải lớn hơn 0.',
        quantity: 0.0
      );
    }
    if (quantity > batch.quantity) {
      return (
        success: false,
        quantity: quantity,
        message: 'Số lượng $quantity kg vượt tồn khả dụng ${batch.quantity} kg.'
      );
    }
    final savedPath = imagePath == null
        ? null
        : await MediaService.save(imagePath, subDirectory: 'damage_reports');
    final success = await damages.createDamageReport(
        batchId: batch.id,
        batchCode: batch.code,
        riceId: batch.riceId,
        riceName: batch.riceName,
        quantity: quantity,
        reason: reason,
        batchProvider: batches,
        note: note.trim().isEmpty ? null : note.trim(),
        imagePath: savedPath,
        createdBy: createdBy);
    return (
      success: success,
      quantity: quantity,
      message: success
          ? null
          : (damages.errorMessage ??
              'Không thể tạo báo hỏng. Kiểm tra lại tồn kho.')
    );
  }
}
