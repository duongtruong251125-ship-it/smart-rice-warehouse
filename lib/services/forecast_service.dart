import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/forecast_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';

class ForecastService {
  const ForecastService();

  /// Phân tích và dự báo tồn kho dựa trên mức tiêu thụ trung bình 7 ngày
  List<ForecastModel> generateForecasts({
    required List<RiceModel> rices,
    required List<ExportReceiptModel> exportReceipts,
    required BatchProvider batchProvider,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Cửa sổ 7 ngày gần nhất (bao gồm cả hôm nay)
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final forecasts = <ForecastModel>[];

    for (final rice in rices) {
      if (!rice.isActive) continue;

      final currentStock = batchProvider.totalStockForRice(rice.id);

      // Lọc các phiếu xuất trong vòng 7 ngày gần nhất
      final recentExports = exportReceipts.where((receipt) {
        if (receipt.riceId != rice.id) return false;
        final receiptDate = DateTime(
          receipt.date.year,
          receipt.date.month,
          receipt.date.day,
        );
        return !receiptDate.isBefore(sevenDaysAgo) &&
            !receiptDate.isAfter(today);
      });

      final totalQuantityExported7Days = recentExports.fold(
        0.0,
        (sum, receipt) => sum + receipt.quantity,
      );

      double dailyExportRate = totalQuantityExported7Days / 7.0;
      bool usedFallback = false;

      // Fallback thông minh: Nếu 7 ngày qua chưa có đơn nhưng trong lịch sử kho có phát sinh xuất
      if (dailyExportRate <= 0.00000001) {
        final allExportsForRice =
            exportReceipts.where((receipt) => receipt.riceId == rice.id).toList();
        if (allExportsForRice.isNotEmpty) {
          final totalHistoryQty =
              allExportsForRice.fold(0.0, (sum, receipt) => sum + receipt.quantity);
          dailyExportRate = totalHistoryQty / 30.0; // Ước tính bình quân 30 ngày
          usedFallback = true;
        }
      }

      double? estimatedDaysRemaining;
      ForecastStatus status;
      String suggestion;

      // Xử lý an toàn: Tránh chia cho 0
      if (dailyExportRate <= 0.00000001) {
        estimatedDaysRemaining = null;
        if (currentStock <= 0) {
          status = ForecastStatus.reorderSoon;
          suggestion =
              'Kho đã hết hàng hoàn toàn. Khuyến nghị nhập tối thiểu ${NumberFormatter.quantity(rice.minimumStock * 2)} ${rice.unit}.';
        } else if (currentStock <= rice.minimumStock) {
          status = ForecastStatus.attention;
          suggestion =
              'Chưa phát sinh đơn xuất gần đây nhưng tồn kho (${NumberFormatter.quantity(currentStock)} ${rice.unit}) đang chạm ngưỡng an toàn (${NumberFormatter.quantity(rice.minimumStock)} ${rice.unit}).';
        } else {
          status = ForecastStatus.safe;
          suggestion =
              'Tồn kho hiện tại (${NumberFormatter.quantity(currentStock)} ${rice.unit}) đảm bảo ổn định. Chưa phát sinh nhu cầu xuất lớn.';
        }
      } else {
        // Có phát sinh xuất kho (theo 7 ngày hoặc theo bình quân lịch sử)
        final days = currentStock / dailyExportRate;
        estimatedDaysRemaining = days;

        if (days <= 7 || currentStock <= rice.minimumStock) {
          status = ForecastStatus.reorderSoon;
          final recommendedReorder =
              ((rice.minimumStock * 2) - currentStock).clamp(50.0, 50000.0);
          suggestion =
              'Tiêu thụ ~${NumberFormatter.quantity(dailyExportRate)} ${rice.unit}/ngày${usedFallback ? " (BQ tháng)" : ""}. '
              'Tồn kho chỉ đủ duy trì trong ${days.toStringAsFixed(1)} ngày. '
              'Khuyến nghị nhập thêm ~${NumberFormatter.quantity(recommendedReorder)} ${rice.unit}!';
        } else if (days <= 14) {
          status = ForecastStatus.attention;
          suggestion =
              'Tiêu thụ ~${NumberFormatter.quantity(dailyExportRate)} ${rice.unit}/ngày. '
              'Tồn kho ước tính đủ dùng trong ${days.toStringAsFixed(1)} ngày. Hãy chuẩn bị liên hệ nhà cung cấp.';
        } else {
          status = ForecastStatus.safe;
          suggestion =
              'Tồn kho an toàn, ước tính đủ đáp ứng khoảng ${days.toStringAsFixed(0)} ngày theo tốc độ tiêu thụ hiện tại.';
        }
      }

      forecasts.add(
        ForecastModel(
          riceId: rice.id,
          riceName: rice.name,
          riceCode: rice.code,
          unit: rice.unit,
          currentStock: currentStock,
          minimumStock: rice.minimumStock,
          averageDailyExport: dailyExportRate,
          estimatedDaysRemaining: estimatedDaysRemaining,
          status: status,
          reorderSuggestion: suggestion,
        ),
      );
    }

    // Sắp xếp mức độ ưu tiên (Ranking): reorderSoon -> attention -> noData -> safe
    forecasts.sort((a, b) {
      final statusOrder =
          _statusWeight(b.status).compareTo(_statusWeight(a.status));
      if (statusOrder != 0) return statusOrder;

      // Nếu cùng status, ưu tiên loại gạo còn số ngày ít hơn
      if (a.estimatedDaysRemaining != null &&
          b.estimatedDaysRemaining != null) {
        return a.estimatedDaysRemaining!.compareTo(b.estimatedDaysRemaining!);
      }
      return a.currentStock.compareTo(b.currentStock);
    });

    return forecasts;
  }

  int _statusWeight(ForecastStatus status) {
    switch (status) {
      case ForecastStatus.reorderSoon:
        return 3;
      case ForecastStatus.attention:
        return 2;
      case ForecastStatus.noData:
        return 1;
      case ForecastStatus.safe:
        return 0;
    }
  }
}
