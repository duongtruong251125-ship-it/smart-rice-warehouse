import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/services/dashboard_service.dart';
import 'package:smart_rice_warehouse/logic/services/report_service.dart';

class DashboardViewModel {
  DashboardViewModel({
    required RiceProvider rices,
    required BatchProvider batches,
    required ImportProvider imports,
    required ExportProvider exports,
    required AlertProvider alerts,
    bool? backgroundSyncEnabled,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    syncStatus = WarehouseSyncStatus.resolve(
      sources: [
        SyncSourceSnapshot(
          usesFirestore: rices.usesFirestore,
          isLoading: rices.isLoading,
          errorMessage: rices.errorMessage,
        ),
        SyncSourceSnapshot(
          usesFirestore: batches.usesFirestore,
          isLoading: batches.isLoading,
          errorMessage: batches.errorMessage,
        ),
        SyncSourceSnapshot(
          usesFirestore: imports.usesFirestore,
          isLoading: imports.isLoading,
          errorMessage: imports.errorMessage,
        ),
        SyncSourceSnapshot(
          usesFirestore: exports.usesFirestore,
          isLoading: exports.isLoading,
          errorMessage: exports.errorMessage,
        ),
      ],
      backgroundSyncEnabled: backgroundSyncEnabled,
    );
    totalTons = batches.totalStock / 1000;
    capacityPercent = (totalTons / 200).clamp(0.0, 1.0);
    availableBatches = batches.batches
        .where((b) =>
            b.status == BatchStatus.available && b.expiryDate.isAfter(now))
        .length;
    nearExpiryBatches = batches.batches
        .where((b) =>
            b.expiryDate.isAfter(now) &&
            b.expiryDate.difference(now).inDays <= 30)
        .length;
    expiredBatches = batches.batches
        .where((b) =>
            b.status == BatchStatus.expired || b.expiryDate.isBefore(now))
        .length;
    final todayImports = imports.receipts.where((r) => isSameDay(r.date, now));
    final todayExports = exports.receipts.where((r) => isSameDay(r.date, now));
    todayImportCount = todayImports.length;
    todayExportCount = todayExports.length;
    todayImportKg = todayImports.fold(0, (sum, r) => sum + r.quantity);
    todayExportKg = todayExports.fold(0, (sum, r) => sum + r.quantity);
    alertImportsCount = alerts.alerts
        .where((a) => a.title.contains('nhập') || a.message.contains('nhập'))
        .length;
    alertExportsCount = alerts.alerts
        .where((a) => a.title.contains('xuất') || a.message.contains('xuất'))
        .length;
    recentActivities = getRecentActivities(
        rices: rices.rices,
        importReceipts: imports.receipts,
        exportReceipts: exports.receipts);
    topRices = getTopStockRices(rices.rices, batches);
    weekChartData =
        getWeekChartData(imports.receipts, exports.receipts, today: now);
  }

  late final WarehouseSyncStatus syncStatus;
  late final double totalTons;
  late final double capacityPercent;
  late final int availableBatches;
  late final int nearExpiryBatches;
  late final int expiredBatches;
  late final int todayImportCount;
  late final int todayExportCount;
  late final double todayImportKg;
  late final double todayExportKg;
  late final int alertImportsCount;
  late final int alertExportsCount;
  late final List<DashboardActivity> recentActivities;
  late final List<RiceStockSummary> topRices;
  late final List<DayFlowData> weekChartData;

  static void refresh({
    required RiceProvider rices,
    required BatchProvider batches,
    required ExportProvider exports,
    required AlertProvider alerts,
    required ForecastProvider forecasts,
  }) {
    alerts.scanAlerts(rices: rices.rices, batches: batches.batches);
    forecasts.refreshForecasts(
        rices: rices.rices,
        exportReceipts: exports.receipts,
        batchProvider: batches);
  }

  static void retryAllSync({
    required RiceProvider rices,
    required BatchProvider batches,
    required ImportProvider imports,
    required ExportProvider exports,
  }) {
    rices.retrySync();
    batches.retrySync();
    imports.retrySync();
    exports.retrySync();
  }
}
