import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/logic/models/forecast_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/logic/services/forecast_service.dart';

class FixedStock extends Fake implements BatchProvider {
  FixedStock(this.stock);
  final double stock;
  @override
  double totalStockForRice(String riceId) => stock;
}

const rice = RiceModel(
    id: 'rice',
    code: 'R',
    name: 'Gạo',
    category: 'Gạo',
    unit: 'kg',
    purchasePrice: 1,
    sellingPrice: 2,
    minimumStock: 20,
    description: '',
    isActive: true);

ExportReceiptModel receipt(DateTime date, double quantity) =>
    ExportReceiptModel(
        id: date.toIso8601String(),
        code: 'PX',
        customerId: 'c',
        customerName: 'C',
        date: date,
        riceId: rice.id,
        riceName: rice.name,
        quantity: quantity,
        sellingPrice: 2,
        totalAmount: quantity * 2,
        note: '');

ForecastModel forecast(List<ExportReceiptModel> receipts,
        {DateTime? now, double stock = 100}) =>
    const ForecastService().generateForecasts(
        rices: [rice],
        exportReceipts: receipts,
        batchProvider: FixedStock(stock),
        referenceDate: now ?? DateTime(2026, 10, 20, 12)).single;

void main() {
  test('includes first and last days, excludes eighth day and tomorrow', () {
    final result = forecast([
      receipt(DateTime(2026, 10, 14), 35),
      receipt(DateTime(2026, 10, 20, 23, 59, 59), 35),
      receipt(DateTime(2026, 10, 13, 23, 59, 59), 700),
      receipt(DateTime(2026, 10, 21), 700),
    ]);
    expect(result.averageDailyExport, 10);
    expect(result.estimatedDaysRemaining, 10);
    expect(result.status, ForecastStatus.attention);
    expect(result.reorderSuggestion, contains('10.0 ngày'));
  });
  test('seven calendar days are divided by seven, not eight', () {
    final result = forecast(
        List.generate(8, (i) => receipt(DateTime(2026, 10, 20 - i), 7)));
    expect(result.averageDailyExport, 7);
  });
  for (final hour in [0, 12, 23]) {
    test('reference hour $hour does not change calendar-day membership', () {
      final result = forecast([
        receipt(DateTime(2026, 10, 14, 23, 59), 21),
        receipt(DateTime(2026, 10, 20, 23, 59), 49),
      ], now: DateTime(2026, 10, 20, hour));
      expect(result.averageDailyExport, 10);
    });
  }
  for (final now in [
    DateTime(2026, 11, 3),
    DateTime(2027, 1, 3),
    DateTime(2024, 3, 2)
  ]) {
    test('calendar window across month/year/leap boundary $now', () {
      final result = forecast([
        receipt(DateTime(now.year, now.month, now.day - 6, 23), 70),
        receipt(DateTime(now.year, now.month, now.day - 7, 23), 700),
        receipt(DateTime(now.year, now.month, now.day + 1), 700),
      ], now: now);
      expect(result.averageDailyExport, 10);
    });
  }
  test('future-only receipts cannot enter historical fallback', () {
    final result = forecast([receipt(DateTime(2026, 10, 21), 3000)]);
    expect(result.averageDailyExport, 0);
    expect(result.estimatedDaysRemaining, isNull);
    expect(result.status, ForecastStatus.safe);
  });
  test('historical fallback keeps divisor 30 and excludes future receipts', () {
    final result = forecast([
      receipt(DateTime(2026, 10, 13), 300),
      receipt(DateTime(2026, 10, 21), 3000),
    ]);
    expect(result.averageDailyExport, 10);
    expect(result.estimatedDaysRemaining, 10);
  });
  test('corrected window affects days/status/reorder without changing formula',
      () {
    final result = forecast([
      receipt(DateTime(2026, 10, 14), 70),
      receipt(DateTime(2026, 10, 13), 700),
    ], stock: 60);
    expect(result.averageDailyExport, 10);
    expect(result.estimatedDaysRemaining, 6);
    expect(result.status, ForecastStatus.reorderSoon);
    expect(result.reorderSuggestion, contains('~50 kg'));
  });
  test('no transactions and zero speed never divide by zero', () {
    for (final receipts in <List<ExportReceiptModel>>[
      [],
      [receipt(DateTime(2026, 10, 20), 0)],
    ]) {
      for (final stock in [0.0, 20.0, 100.0]) {
        final result = forecast(receipts, stock: stock);
        expect(result.averageDailyExport, 0);
        expect(result.estimatedDaysRemaining, isNull);
        expect(
            result.status,
            stock == 0
                ? ForecastStatus.reorderSoon
                : stock == 20
                    ? ForecastStatus.attention
                    : ForecastStatus.safe);
      }
    }
  });
  test('ForecastProvider forwards fixed reference and corrected results', () {
    final provider = ForecastProvider();
    addTearDown(provider.dispose);
    provider.refreshForecasts(
        rices: [
          rice
        ],
        exportReceipts: [
          receipt(DateTime(2026, 10, 14), 70),
          receipt(DateTime(2026, 10, 13), 700),
        ],
        batchProvider: FixedStock(60),
        referenceDate: DateTime(2026, 10, 20, 12));
    expect(provider.forecasts.single.averageDailyExport, 10);
    expect(provider.reorderSoonCount, 1);
  });
}
