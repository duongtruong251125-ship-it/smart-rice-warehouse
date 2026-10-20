import 'package:smart_rice_warehouse/logic/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';

class DashboardActivity {
  const DashboardActivity({
    required this.isImport,
    required this.code,
    required this.riceName,
    required this.quantity,
    required this.unit,
    required this.date,
  });

  final bool isImport;
  final String code;
  final String riceName;
  final double quantity;
  final String unit;
  final DateTime date;
}

class DayFlowData {
  const DayFlowData({
    required this.dayLabel,
    required this.importKg,
    required this.exportKg,
  });

  final String dayLabel;
  final double importKg;
  final double exportKg;
}

class RiceStockSummary {
  const RiceStockSummary({
    required this.name,
    required this.code,
    required this.stockKg,
    required this.unit,
  });

  final String name;
  final String code;
  final double stockKg;
  final String unit;
}

List<DayFlowData> getWeekChartData(
  List<ImportReceiptModel> importReceipts,
  List<ExportReceiptModel> exportReceipts, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final list = <DayFlowData>[];

  for (var i = 6; i >= 0; i--) {
    final d = now.subtract(Duration(days: i));
    final dayLabel =
        i == 0 ? 'Nay' : 'T${d.weekday == 7 ? "CN" : (d.weekday + 1)}';

    final importKg = importReceipts.where((r) {
      final rd = r.date;
      return rd.year == d.year && rd.month == d.month && rd.day == d.day;
    }).fold<double>(0.0, (s, r) => s + r.quantity);

    final exportKg = exportReceipts.where((r) {
      final rd = r.date;
      return rd.year == d.year && rd.month == d.month && rd.day == d.day;
    }).fold<double>(0.0, (s, r) => s + r.quantity);

    list.add(DayFlowData(
      dayLabel: dayLabel,
      importKg: importKg,
      exportKg: exportKg,
    ));
  }
  return list;
}

List<RiceStockSummary> getTopStockRices(
  List<RiceModel> rices,
  BatchProvider batchProvider,
) {
  final list = rices.where((r) => r.isActive).map((r) {
    return RiceStockSummary(
      name: r.name,
      code: r.code,
      stockKg: batchProvider.totalStockForRice(r.id),
      unit: r.unit,
    );
  }).toList();

  list.sort((a, b) => b.stockKg.compareTo(a.stockKg));
  return list.take(3).toList();
}

List<DashboardActivity> getRecentActivities({
  required List<RiceModel> rices,
  required List<ImportReceiptModel> importReceipts,
  required List<ExportReceiptModel> exportReceipts,
}) {
  final unitsByRiceId = <String, String>{
    for (final rice in rices) rice.id: rice.unit,
  };
  final activities = <DashboardActivity>[
    for (final receipt in importReceipts)
      DashboardActivity(
        isImport: true,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
    for (final receipt in exportReceipts)
      DashboardActivity(
        isImport: false,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
  ]..sort((first, second) => second.date.compareTo(first.date));

  return activities.take(5).toList(growable: false);
}
