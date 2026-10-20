import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';

/// Chính sách di chuyển và nâng cấp dữ liệu seed trong SQLite cục bộ.
///
/// Tách rời quy tắc nâng cấp dữ liệu khỏi driver SQLite giúp kiểm thử logic
/// bảo toàn dữ liệu cũ, không ghi đè khi thiếu marker và không làm lẫn lộn
/// lịch sử giao dịch thật của người dùng.
class SeedMigrationPolicy {
  const SeedMigrationPolicy();

  /// Quyết định xem có bỏ qua việc ghi đè dữ liệu mẫu ban đầu hay không.
  /// Nếu cơ sở dữ liệu đã có dữ liệu trước đó (kể cả khi chưa có marker version),
  /// phải bảo toàn dữ liệu người dùng, KHÔNG ghi đè MockData.
  bool shouldSkipInitialSeedOverwrite({
    required int installedVersion,
    required bool hasExistingData,
  }) {
    if (installedVersion == 0 && hasExistingData) {
      return true;
    }
    return false;
  }

  /// Nâng cấp danh mục gạo từ v1 lên v2:
  /// Chỉ bổ sung đường dẫn ảnh cho các gạo mẫu nếu còn thiếu,
  /// giữ nguyên toàn bộ các gạo và ảnh do người dùng tự tạo.
  List<RiceModel> migrateRicesV1ToV2({
    required List<RiceModel> existingRices,
    required List<RiceModel> sampleRices,
  }) {
    final sampleImages = <String, String>{
      for (final rice in sampleRices)
        if (rice.imagePath != null && rice.imagePath!.trim().isNotEmpty)
          rice.id: rice.imagePath!,
    };

    return existingRices.map((rice) {
      final sampleImage = sampleImages[rice.id];
      if (rice.imagePath != null && rice.imagePath!.trim().isNotEmpty) {
        return rice;
      }
      if (sampleImage != null) {
        return rice.copyWith(imagePath: sampleImage);
      }
      return rice;
    }).toList();
  }

  /// Nâng cấp biên bản báo hỏng từ v2 lên v3:
  /// Tuyệt đối KHÔNG chèn thêm danh sách báo hỏng mẫu vào lịch sử của người dùng.
  /// Chỉ cập nhật ảnh cho biên bản mẫu cũ nếu chưa có ảnh, bảo toàn 100% báo cáo người dùng.
  List<DamageReportModel> migrateDamageReportsV2ToV3({
    required List<DamageReportModel> existingReports,
    required List<DamageReportModel> sampleReports,
  }) {
    if (existingReports.isEmpty) return const [];

    final samplesById = <String, DamageReportModel>{
      for (final report in sampleReports) report.id: report,
    };

    return existingReports.map((report) {
      final sample = samplesById[report.id];
      if (sample == null ||
          report.imagePath?.trim().isNotEmpty == true ||
          sample.imagePath == null) {
        return report;
      }
      return report.copyWith(imagePath: sample.imagePath);
    }).toList();
  }

  /// Nâng cấp cơ sở dữ liệu lên Version 4:
  /// Tuyệt đối KHÔNG thêm lô hàng hoặc giao dịch mẫu vào database đang hoạt động,
  /// cũng không khôi phục dữ liệu mẫu người dùng đã xóa.
  /// Chỉ cập nhật bổ sung đường dẫn ảnh mẫu nếu bản ghi mẫu tương ứng vẫn đang tồn tại.
  List<RiceModel> migrateRicesV3ToV4({
    required List<RiceModel> existingRices,
    required List<RiceModel> sampleRices,
  }) {
    return migrateRicesV1ToV2(
      existingRices: existingRices,
      sampleRices: sampleRices,
    );
  }
}
