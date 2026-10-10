import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';

class DamageProvider extends ChangeNotifier {
  DamageProvider({List<DamageReportModel>? initial, this.onPersist}) {
    _reports = List<DamageReportModel>.from(
      initial ?? MockData.initialDamageReports,
    );
  }

  late List<DamageReportModel> _reports;
  final ValueChanged<List<DamageReportModel>>? onPersist;

  List<DamageReportModel> get reports =>
      List<DamageReportModel>.unmodifiable(_reports);

  double get totalDamagedWeight =>
      _reports.fold<double>(0.0, (sum, r) => sum + r.quantity);

  /// Tạo và xác nhận báo hỏng -> Giảm tồn kho của Batch tương ứng
  bool createDamageReport({
    required String batchId,
    required String batchCode,
    required String riceId,
    required String riceName,
    required double quantity,
    required DamageReason reason,
    required BatchProvider batchProvider,
    String? note,
    String? imagePath,
    String createdBy = 'Admin',
  }) {
    if (quantity <= 0) return false;

    final batch = batchProvider.findById(batchId);
    if (batch == null || batch.quantity < quantity) {
      return false; // Số lượng báo hỏng vượt quá tồn hiện có
    }

    final now = DateTime.now();
    final code =
        'BH-${now.year}${now.month.toString().padLeft(2, '0')}-${(_reports.length + 1).toString().padLeft(3, '0')}';

    final report = DamageReportModel(
      id: 'damage-${now.millisecondsSinceEpoch}',
      code: code,
      batchId: batchId,
      batchCode: batchCode,
      riceId: riceId,
      riceName: riceName,
      quantity: quantity,
      reason: reason,
      note: note,
      imagePath: imagePath,
      createdBy: createdBy,
      createdAt: now,
      status: DamageReportStatus.confirmed,
    );

    // Giảm tồn của batch trong BatchProvider
    final success = batchProvider.reportDamage(
      batchId: batchId,
      damagedQuantity: quantity,
    );

    if (success) {
      _reports.insert(0, report);
      onPersist?.call(reports);
      notifyListeners();
      return true;
    }
    return false;
  }

  List<DamageReportModel> filter({DamageReason? reason, String? keyword}) {
    return _reports.where((r) {
      if (reason != null && r.reason != reason) return false;
      if (keyword != null && keyword.trim().isNotEmpty) {
        final q = keyword.trim().toLowerCase();
        final matchCode = r.code.toLowerCase().contains(q);
        final matchBatch = r.batchCode.toLowerCase().contains(q);
        final matchRice = r.riceName.toLowerCase().contains(q);
        if (!matchCode && !matchBatch && !matchRice) return false;
      }
      return true;
    }).toList();
  }

  DamageReportModel? findById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
