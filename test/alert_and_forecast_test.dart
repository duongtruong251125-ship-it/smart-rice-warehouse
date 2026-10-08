import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/alert_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/forecast_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/services/forecast_service.dart';

void main() {
  group('Week 2 - Alert Detection Test Cases', () {
    final alertProvider = AlertProvider();
    final today = DateTime(2026, 10, 1);

    RiceModel makeRice({
      required String id,
      required String name,
      required double minStock,
    }) {
      return RiceModel(
        id: id,
        code: 'RICE-$id',
        name: name,
        category: 'Gạo',
        unit: 'kg',
        purchasePrice: 20000,
        sellingPrice: 25000,
        minimumStock: minStock,
        description: '',
        isActive: true,
      );
    }

    BatchModel makeBatch({
      required String id,
      required String riceId,
      required double quantity,
      required DateTime expiryDate,
      BatchStatus status = BatchStatus.available,
    }) {
      return BatchModel(
        id: id,
        code: 'LOT-$id',
        riceId: riceId,
        riceName: 'Gạo',
        quantity: quantity,
        importDate: DateTime(2026, 9, 1),
        manufactureDate: DateTime(2026, 8, 1),
        expiryDate: expiryDate,
        status: status,
      );
    }

    test('Low stock tests: currentStock > min (normal), = min (lowStock), < min (lowStock)', () {
      final rices = [
        makeRice(id: 'r1', name: 'Gạo Normal', minStock: 100),
        makeRice(id: 'r2', name: 'Gạo Equal', minStock: 100),
        makeRice(id: 'r3', name: 'Gạo Less', minStock: 100),
      ];

      final batches = [
        makeBatch(
          id: 'b1',
          riceId: 'r1',
          quantity: 150, // 150 > 100 -> normal
          expiryDate: DateTime(2027, 1, 1),
        ),
        makeBatch(
          id: 'b2',
          riceId: 'r2',
          quantity: 100, // 100 == 100 -> low stock
          expiryDate: DateTime(2027, 1, 1),
        ),
        makeBatch(
          id: 'b3',
          riceId: 'r3',
          quantity: 50, // 50 < 100 -> low stock
          expiryDate: DateTime(2027, 1, 1),
        ),
      ];

      alertProvider.scanAlerts(
        rices: rices,
        batches: batches,
        referenceDate: today,
      );

      final lowStockAlerts = alertProvider.alerts
          .where((a) => a.type == AlertType.lowStock)
          .toList();

      expect(lowStockAlerts.any((a) => a.riceId == 'r1'), isFalse);
      expect(lowStockAlerts.any((a) => a.riceId == 'r2'), isTrue);
      expect(lowStockAlerts.any((a) => a.riceId == 'r3'), isTrue);
    });

    test('Expiry tests: > 30 days (normal), 15 days (warning), 5 days (critical), expired (expired)', () {
      final rices = [makeRice(id: 'r1', name: 'Gạo', minStock: 10)];

      final batches = [
        makeBatch(
          id: 'b-normal',
          riceId: 'r1',
          quantity: 100,
          expiryDate: today.add(const Duration(days: 45)), // > 30 days
        ),
        makeBatch(
          id: 'b-15d',
          riceId: 'r1',
          quantity: 100,
          expiryDate: today.add(const Duration(days: 15)), // 8-30 days -> warning
        ),
        makeBatch(
          id: 'b-5d',
          riceId: 'r1',
          quantity: 100,
          expiryDate: today.add(const Duration(days: 5)), // 1-7 days -> critical
        ),
        makeBatch(
          id: 'b-past',
          riceId: 'r1',
          quantity: 100,
          expiryDate: today.subtract(const Duration(days: 2)), // expired
        ),
      ];

      alertProvider.scanAlerts(
        rices: rices,
        batches: batches,
        referenceDate: today,
      );

      final expiryAlerts = alertProvider.alerts
          .where((a) => a.type != AlertType.lowStock)
          .toList();

      // Normal batch (> 30 days) has no alert
      expect(expiryAlerts.any((a) => a.batchId == 'b-normal'), isFalse);

      // 15 days -> warning
      final alert15d = expiryAlerts.firstWhere((a) => a.batchId == 'b-15d');
      expect(alert15d.severity, AlertSeverity.warning);
      expect(alert15d.type, AlertType.expiringSoon);

      // 5 days -> critical
      final alert5d = expiryAlerts.firstWhere((a) => a.batchId == 'b-5d');
      expect(alert5d.severity, AlertSeverity.critical);
      expect(alert5d.type, AlertType.expiringSoon);

      // Expired -> expired & critical
      final alertPast = expiryAlerts.firstWhere((a) => a.batchId == 'b-past');
      expect(alertPast.severity, AlertSeverity.critical);
      expect(alertPast.type, AlertType.expired);
    });
  });

  group('Week 2 - Forecast Engine Test Cases', () {
    const forecastService = ForecastService();
    final today = DateTime(2026, 10, 8);

    RiceModel makeRice({
      required String id,
      required String name,
      required double minStock,
    }) {
      return RiceModel(
        id: id,
        code: 'RICE-$id',
        name: name,
        category: 'Gạo',
        unit: 'kg',
        purchasePrice: 20000,
        sellingPrice: 25000,
        minimumStock: minStock,
        description: '',
        isActive: true,
      );
    }

    test('Forecast: Có lịch sử xuất vs Không có lịch sử xuất (Average = 0) - Không crash chia 0', () {
      final batchProvider = BatchProvider();
      final rices = [
        makeRice(id: 'rice-st25', name: 'ST25', minStock: 200),
        makeRice(id: 'rice-unused', name: 'Chưa xuất', minStock: 100),
      ];

      // Thêm 1 phiếu xuất 70kg vào hôm qua cho rice-st25
      final receipts = [
        ExportReceiptModel(
          id: 'exp-1',
          code: 'PX-01',
          customerId: 'cust-1',
          customerName: 'Khách',
          date: today.subtract(const Duration(days: 1)),
          riceId: 'rice-st25',
          riceName: 'ST25',
          quantity: 70, // 70 / 7 = 10 kg/ngày
          sellingPrice: 30000,
          totalAmount: 2100000,
          note: '',
        ),
      ];

      final forecasts = forecastService.generateForecasts(
        rices: rices,
        exportReceipts: receipts,
        batchProvider: batchProvider,
        referenceDate: today,
      );

      final st25Forecast = forecasts.firstWhere((f) => f.riceId == 'rice-st25');
      expect(st25Forecast.averageDailyExport, closeTo(10.0, 0.001));
      expect(st25Forecast.estimatedDaysRemaining, isNotNull);
      expect(st25Forecast.status, isNot(ForecastStatus.noData));

      final unusedForecast =
          forecasts.firstWhere((f) => f.riceId == 'rice-unused');
      expect(unusedForecast.averageDailyExport, 0.0);
      expect(unusedForecast.estimatedDaysRemaining, isNull);
      // Chia 0 không crash
    });

    test('Forecast: Inventory = 0 -> reorderSoon', () {
      final batchProvider = BatchProvider();
      // rice-none không có batch nào
      final rices = [
        makeRice(id: 'rice-zero-stock', name: 'Hết hàng', minStock: 100),
      ];

      final forecasts = forecastService.generateForecasts(
        rices: rices,
        exportReceipts: [],
        batchProvider: batchProvider,
        referenceDate: today,
      );

      final forecast = forecasts.first;
      expect(forecast.currentStock, 0.0);
      expect(forecast.status, ForecastStatus.reorderSoon);
    });

    test('Forecast: Export tăng mạnh -> daysRemaining giảm và status reorderSoon', () {
      final batchProvider = BatchProvider();
      final rices = [
        makeRice(id: 'rice-st25', name: 'ST25', minStock: 100),
      ];

      // Export 7000kg trong 7 ngày -> TB 1000kg/ngày
      final receipts = [
        ExportReceiptModel(
          id: 'exp-surge',
          code: 'PX-SURGE',
          customerId: 'cust-1',
          customerName: 'Khách',
          date: today.subtract(const Duration(days: 2)),
          riceId: 'rice-st25',
          riceName: 'ST25',
          quantity: 7000,
          sellingPrice: 30000,
          totalAmount: 210000000,
          note: '',
        ),
      ];

      final forecasts = forecastService.generateForecasts(
        rices: rices,
        exportReceipts: receipts,
        batchProvider: batchProvider,
        referenceDate: today,
      );

      final forecast = forecasts.first;
      expect(forecast.averageDailyExport, 1000.0);
      expect(forecast.estimatedDaysRemaining, lessThan(5.0));
      expect(forecast.status, ForecastStatus.reorderSoon);
    });
  });
}
