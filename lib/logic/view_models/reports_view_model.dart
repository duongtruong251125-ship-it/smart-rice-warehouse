import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/logic/models/report_chart_data.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/services/report_service.dart';

/// Prepared report data. Recreate when source data changes, not for UI toggles.
class ReportsViewModel {
  ReportsViewModel({
    required this.date,
    required List<ImportReceiptModel> imports,
    required List<ExportReceiptModel> exports,
    required List<BatchModel> batches,
    required List<RiceModel> rices,
    required List<InventorySnapshotModel> snapshots,
    required this.inventoryValue,
    required this.totalStock,
  }) {
    monthImports = imports
        .where((r) => r.date.year == date.year && r.date.month == date.month)
        .toList();
    monthExports = exports
        .where((r) => r.date.year == date.year && r.date.month == date.month)
        .toList();
    monthImportAmount = monthImports.fold(0, (sum, r) => sum + r.totalAmount);
    monthExportAmount = monthExports.fold(0, (sum, r) => sum + r.totalAmount);
    monthImportQuantity = monthImports.fold(0, (sum, r) => sum + r.quantity);
    monthExportQuantity = monthExports.fold(0, (sum, r) => sum + r.quantity);
    activities = buildDailyActivities(
      today: date,
      importReceipts: imports,
      exportReceipts: exports,
    );
    total7DaysImport = activities.fold(0, (sum, a) => sum + a.importQuantity);
    total7DaysExport = activities.fold(0, (sum, a) => sum + a.exportQuantity);
    topExportedRices =
        calculateTopExportedRices(exportReceipts: exports, rices: rices);
    weeklyData = buildMonthlyWeeklyBars(
      importReceipts: monthImports,
      exportReceipts: monthExports,
    );
    inventorySlices =
        buildInventorySlices(batches: batches, rices: rices, today: date);
    inventoryQuantity =
        inventorySlices.fold(0, (sum, item) => sum + item.quantity);
    inventoryValuePoints = buildInventoryValuePoints(
      snapshots: snapshots,
      today: date,
      currentValue: inventoryValue,
      importReceipts: imports,
      exportReceipts: exports,
      rices: rices,
    );
  }

  final DateTime date;
  final double inventoryValue;
  final double totalStock;
  late final List<ImportReceiptModel> monthImports;
  late final List<ExportReceiptModel> monthExports;
  late final double monthImportAmount;
  late final double monthExportAmount;
  late final double monthImportQuantity;
  late final double monthExportQuantity;
  late final double total7DaysImport;
  late final double total7DaysExport;
  late final double inventoryQuantity;
  late final List<DailyActivity> activities;
  late final List<TopExportedItem> topExportedRices;
  late final List<WeeklyBarData> weeklyData;
  late final List<InventoryQuantity> inventorySlices;
  late final List<ReportValuePoint> inventoryValuePoints;
}
