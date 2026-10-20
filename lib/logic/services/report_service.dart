import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_snapshot_model.dart';
import 'package:smart_rice_warehouse/logic/models/report_chart_data.dart';

class TopExportedItem {
  const TopExportedItem({
    required this.riceId,
    required this.riceName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  final String riceId;
  final String riceName;
  final String unit;
  final double totalQuantity;
  final double totalRevenue;
}

List<TopExportedItem> calculateTopExportedRices({
  required List<ExportReceiptModel> exportReceipts,
  required List<RiceModel> rices,
}) {
  final quantities = <String, double>{};
  final revenues = <String, double>{};

  for (final receipt in exportReceipts) {
    quantities[receipt.riceId] =
        (quantities[receipt.riceId] ?? 0.0) + receipt.quantity;
    revenues[receipt.riceId] =
        (revenues[receipt.riceId] ?? 0.0) + receipt.totalAmount;
  }

  final items = <TopExportedItem>[];
  for (final entry in quantities.entries) {
    final rice = rices.cast<RiceModel?>().firstWhere(
          (r) => r?.id == entry.key,
          orElse: () => null,
        );
    items.add(
      TopExportedItem(
        riceId: entry.key,
        riceName: rice?.name ?? entry.key,
        unit: rice?.unit ?? 'kg',
        totalQuantity: entry.value,
        totalRevenue: revenues[entry.key] ?? 0.0,
      ),
    );
  }

  items.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
  return items.take(5).toList(growable: false);
}

class WeeklyBarData {
  const WeeklyBarData({
    required this.label,
    required this.importQty,
    required this.exportQty,
  });

  final String label;
  final double importQty;
  final double exportQty;
}

List<WeeklyBarData> buildMonthlyWeeklyBars({
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
}) {
  final importQtys = [0.0, 0.0, 0.0, 0.0];
  final exportQtys = [0.0, 0.0, 0.0, 0.0];

  for (final r in importReceipts) {
    final day = r.date.day;
    final index = (day <= 7)
        ? 0
        : (day <= 14)
            ? 1
            : (day <= 21)
                ? 2
                : 3;
    importQtys[index] += r.quantity;
  }

  for (final r in exportReceipts) {
    final day = r.date.day;
    final index = (day <= 7)
        ? 0
        : (day <= 14)
            ? 1
            : (day <= 21)
                ? 2
                : 3;
    exportQtys[index] += r.quantity;
  }

  final labels = [
    'Tuần 1 (1-7)',
    'Tuần 2 (8-14)',
    'Tuần 3 (15-21)',
    'Tuần 4 (22+)'
  ];
  return List.generate(4, (i) {
    return WeeklyBarData(
      label: labels[i],
      importQty: importQtys[i],
      exportQty: exportQtys[i],
    );
  });
}

class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.importQuantity,
    required this.exportQuantity,
  });

  final DateTime date;
  final double importQuantity;
  final double exportQuantity;
}

List<DailyActivity> buildDailyActivities({
  required DateTime today,
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
}) {
  final currentDay = DateTime(today.year, today.month, today.day);
  return List<DailyActivity>.generate(7, (index) {
    final date = currentDay.subtract(Duration(days: 6 - index));
    return DailyActivity(
      date: date,
      importQuantity: importReceipts
          .where((r) => isSameDay(r.date, date))
          .fold(0.0, (sum, r) => sum + r.quantity),
      exportQuantity: exportReceipts
          .where((r) => isSameDay(r.date, date))
          .fold(0.0, (sum, r) => sum + r.quantity),
    );
  });
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<InventoryQuantity> buildInventorySlices({
  required List<BatchModel> batches,
  required List<RiceModel> rices,
  required DateTime today,
}) {
  final startOfToday = DateTime(today.year, today.month, today.day);
  final namesById = {for (final rice in rices) rice.id: rice.name};
  final quantities = <String, double>{};

  for (final batch in batches) {
    final expiry = DateTime(
      batch.expiryDate.year,
      batch.expiryDate.month,
      batch.expiryDate.day,
    );
    if (batch.quantity <= 0 ||
        batch.status == BatchStatus.expired ||
        expiry.isBefore(startOfToday)) {
      continue;
    }
    quantities.update(
      batch.riceId,
      (value) => value + batch.quantity,
      ifAbsent: () => batch.quantity,
    );
  }

  final sorted = quantities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final visible = sorted.take(4).toList();
  final otherQuantity = sorted.skip(4).fold<double>(
        0,
        (sum, entry) => sum + entry.value,
      );

  final result = List<InventoryQuantity>.generate(
    visible.length,
    (index) => InventoryQuantity(
      label: namesById[visible[index].key] ?? visible[index].key,
      quantity: visible[index].value,
    ),
  );
  if (otherQuantity > 0) {
    result.add(
      InventoryQuantity(
        label: 'Khác',
        quantity: otherQuantity,
      ),
    );
  }
  return result;
}

List<ReportValuePoint> buildInventoryValuePoints({
  required List<InventorySnapshotModel> snapshots,
  required DateTime today,
  required double currentValue,
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
  required List<RiceModel> rices,
}) {
  final pricesByRiceId = {
    for (final rice in rices) rice.id: rice.purchasePrice,
  };
  final startOfToday = DateTime(today.year, today.month, today.day);
  final snapshotValues = <DateTime, double>{
    for (final snapshot in snapshots)
      DateTime(snapshot.date.year, snapshot.date.month, snapshot.date.day):
          snapshot.totalValue,
  };

  return List.generate(7, (index) {
    final date = startOfToday.subtract(Duration(days: 6 - index));
    final snapshotValue = snapshotValues[date];
    if (snapshotValue != null) {
      return ReportValuePoint(date: date, value: snapshotValue);
    }
    final nextDay = date.add(const Duration(days: 1));
    final laterImports = importReceipts
        .where((receipt) => !receipt.date.isBefore(nextDay))
        .fold<double>(0, (sum, receipt) => sum + receipt.totalAmount);
    final laterExportCost = exportReceipts
        .where((receipt) => !receipt.date.isBefore(nextDay))
        .fold<double>(
          0,
          (sum, receipt) =>
              sum +
              receipt.quantity *
                  (pricesByRiceId[receipt.riceId] ?? receipt.sellingPrice),
        );
    return ReportValuePoint(
      date: date,
      value: (currentValue - laterImports + laterExportCost).clamp(
        0,
        double.infinity,
      ),
    );
  });
}
