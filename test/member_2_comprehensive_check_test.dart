import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/data/mock_data.dart';
import 'package:smart_rice_warehouse/models/alert_model.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/screens/reports/reports_tab.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';
import 'package:smart_rice_warehouse/services/forecast_service.dart';
import 'package:smart_rice_warehouse/services/ocr_service.dart';

void main() {
  group('Kiểm tra toàn diện 6 mục Member 2 theo yêu cầu', () {
    // ----------------------------------------------------
    // MỤC 1: Thuật toán Xuất kho FEFO & Phân bổ lô
    // ----------------------------------------------------
    test('Mục 1: Thuật toán FEFO phân bổ đúng lô cận hạn trước, trừ kho chính xác', () {
      const fefoService = FefoService();
      final today = DateTime(2026, 10, 1);

      final batchA = BatchModel(
        id: 'b-01',
        code: 'LOT-EXP-EARLY',
        riceId: 'rice-st25',
        riceName: 'Gạo ST25',
        quantity: 200,
        importDate: DateTime(2026, 8, 1),
        manufactureDate: DateTime(2026, 7, 20),
        expiryDate: DateTime(2026, 10, 15), // Hết hạn sớm hơn
        status: BatchStatus.available,
      );
      final batchB = BatchModel(
        id: 'b-02',
        code: 'LOT-EXP-LATE',
        riceId: 'rice-st25',
        riceName: 'Gạo ST25',
        quantity: 300,
        importDate: DateTime(2026, 9, 1),
        manufactureDate: DateTime(2026, 8, 20),
        expiryDate: DateTime(2026, 12, 1), // Hết hạn trễ hơn
        status: BatchStatus.available,
      );

      // Cần xuất 350kg -> Phải lấy 200kg từ LOT-EXP-EARLY và 150kg từ LOT-EXP-LATE
      final result = fefoService.allocate(
        batches: [batchB, batchA], // Đưa vào thứ tự lộn xộn để kiểm tra sort
        riceId: 'rice-st25',
        quantity: 350,
        currentDate: today,
      );

      expect(result.isSuccess, isTrue);
      expect(result.allocations.length, 2);
      expect(result.allocations[0].batchCode, 'LOT-EXP-EARLY');
      expect(result.allocations[0].allocatedQuantity, 200);
      expect(result.allocations[0].batchRemainingQuantity, 0);

      expect(result.allocations[1].batchCode, 'LOT-EXP-LATE');
      expect(result.allocations[1].allocatedQuantity, 150);
      expect(result.allocations[1].batchRemainingQuantity, 150);

      // Thử xuất quá tồn (600kg > 500kg khả dụng) -> phải reject
      final failResult = fefoService.allocate(
        batches: [batchA, batchB],
        riceId: 'rice-st25',
        quantity: 600,
        currentDate: today,
      );
      expect(failResult.isSuccess, isFalse);
      expect(failResult.errorMessage, contains('Tồn kho khả dụng không đủ'));
    });

    // ----------------------------------------------------
    // MỤC 2: Banner Kho Thông Minh & Chuông cảnh báo trên Trang chủ
    // ----------------------------------------------------
    test('Mục 2: AlertProvider quét dữ liệu thực tế, phát hiện lô cận hạn và tồn thấp', () {
      final alertProvider = AlertProvider();
      final now = DateTime.now();

      final rices = [
        const RiceModel(
          id: 'r1',
          code: 'ST25',
          name: 'Gạo ST25',
          category: 'Thơm',
          unit: 'kg',
          purchasePrice: 20000,
          sellingPrice: 25000,
          minimumStock: 500, // min = 500
          description: '',
          isActive: true,
        ),
      ];

      final batches = [
        BatchModel(
          id: 'b-low',
          code: 'LO-LOW',
          riceId: 'r1',
          riceName: 'Gạo ST25',
          quantity: 200, // Tồn 200 <= min 500 -> Low stock!
          importDate: now.subtract(const Duration(days: 10)),
          manufactureDate: now.subtract(const Duration(days: 20)),
          expiryDate: now.add(const Duration(days: 5)), // Còn 5 ngày -> Critical expiring!
          status: BatchStatus.available,
        ),
      ];

      alertProvider.scanAlerts(rices: rices, batches: batches, referenceDate: now);

      expect(alertProvider.alerts.isNotEmpty, isTrue);
      expect(alertProvider.lowStockCount, greaterThanOrEqualTo(1));
      expect(alertProvider.expiringCount, greaterThanOrEqualTo(1));
      expect(alertProvider.criticalCount, greaterThanOrEqualTo(1));
      expect(alertProvider.unreadCount, alertProvider.alerts.length);

      // Test đánh dấu đã đọc
      alertProvider.markAllAsRead();
      expect(alertProvider.unreadCount, 0);
    });

    // ----------------------------------------------------
    // MỤC 3: Hệ thống Cảnh báo kho (Smart Alerts) & Bộ lọc
    // ----------------------------------------------------
    test('Mục 3: Cảnh báo phân loại đúng loại (lowStock, expiringSoon, expired)', () {
      final alertProvider = AlertProvider();
      final now = DateTime.now();

      final rices = [
        const RiceModel(
          id: 'r-st25',
          code: 'ST25',
          name: 'Gạo ST25',
          category: 'Thơm',
          unit: 'kg',
          purchasePrice: 20000,
          sellingPrice: 25000,
          minimumStock: 100,
          description: '',
          isActive: true,
        ),
      ];

      final batches = [
        BatchModel(
          id: 'b-exp-warn',
          code: 'LO-WARN',
          riceId: 'r-st25',
          riceName: 'Gạo ST25',
          quantity: 300,
          importDate: now,
          manufactureDate: now,
          expiryDate: now.add(const Duration(days: 20)), // 20 ngày -> warning expiringSoon
          status: BatchStatus.available,
        ),
        BatchModel(
          id: 'b-expired',
          code: 'LO-EXPIRED',
          riceId: 'r-st25',
          riceName: 'Gạo ST25',
          quantity: 50,
          importDate: now.subtract(const Duration(days: 40)),
          manufactureDate: now.subtract(const Duration(days: 60)),
          expiryDate: now.subtract(const Duration(days: 2)), // Đã hết hạn -> expired
          status: BatchStatus.expired,
        ),
      ];

      alertProvider.scanAlerts(rices: rices, batches: batches, referenceDate: now);

      final expiredAlerts = alertProvider.alerts.where((a) => a.type == AlertType.expired).toList();
      final expiringAlerts = alertProvider.alerts.where((a) => a.type == AlertType.expiringSoon).toList();

      expect(expiredAlerts.length, 1);
      expect(expiredAlerts.first.batchCode, 'LO-EXPIRED');

      expect(expiringAlerts.length, 1);
      expect(expiringAlerts.first.batchCode, 'LO-WARN');
    });

    // ----------------------------------------------------
    // MỤC 4: Dự báo nhu cầu AI & An toàn chia 0
    // ----------------------------------------------------
    test('Mục 4: Forecast Service tính xuất TB 7 ngày, Days Remaining và không chia 0', () {
      const forecastService = ForecastService();
      final now = DateTime(2026, 10, 8);

      final rices = [
        const RiceModel(
          id: 'r-active',
          code: 'ST25',
          name: 'Gạo ST25',
          category: 'Thơm',
          unit: 'kg',
          purchasePrice: 20000,
          sellingPrice: 25000,
          minimumStock: 100,
          description: '',
          isActive: true,
        ),
        const RiceModel(
          id: 'r-no-export',
          code: 'JAS',
          name: 'Gạo Jasmine',
          category: 'Thơm',
          unit: 'kg',
          purchasePrice: 18000,
          sellingPrice: 22000,
          minimumStock: 50,
          description: '',
          isActive: true,
        ),
      ];

      final batchProvider = BatchProvider();

      final exports = [
        ExportReceiptModel(
          id: 'ex-1',
          code: 'PX001',
          customerId: 'c1',
          customerName: 'Khách A',
          date: DateTime(2026, 10, 5),
          riceId: 'r-active',
          riceName: 'Gạo ST25',
          quantity: 700, // Xuất 700kg trong 7 ngày -> TB 100kg/ngày
          sellingPrice: 25000,
          totalAmount: 17500000,
          note: 'Xuất mẫu kiểm tra',
        ),
      ];

      final forecasts = forecastService.generateForecasts(
        rices: rices,
        exportReceipts: exports,
        batchProvider: batchProvider,
        referenceDate: now,
      );

      final st25Forecast = forecasts.firstWhere((f) => f.riceId == 'r-active');
      expect(st25Forecast.averageDailyExport, 100);
      expect(st25Forecast.estimatedDaysRemaining, greaterThanOrEqualTo(0));

      // Mặt hàng không có xuất -> average = 0, không crash chia 0
      final jasForecast = forecasts.firstWhere((f) => f.riceId == 'r-no-export');
      expect(jasForecast.averageDailyExport, 0);
      expect(jasForecast.estimatedDaysRemaining, isNull);
    });

    // ----------------------------------------------------
    // MỤC 5: Tab Báo cáo Thống kê & 2 bảng tổng nhập/xuất có cột
    // ----------------------------------------------------
    testWidgets('Mục 5: Báo cáo hiển thị thẻ tổng quan, biểu đồ cột tuần và 2 bảng 5 cột', (tester) async {
      final batchProvider = BatchProvider();
      final importProvider = ImportProvider(batchProvider, null);
      final exportProvider = ExportProvider(batchProvider, null);
      final riceProvider = RiceProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: batchProvider),
            ChangeNotifierProvider.value(value: importProvider),
            ChangeNotifierProvider.value(value: exportProvider),
            ChangeNotifierProvider.value(value: riceProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReportsTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra sự hiện diện của Thẻ Tổng quan tháng
      expect(find.text('Tổng quan tháng này'), findsOneWidget);
      expect(find.text('Tổng nhập tháng'), findsOneWidget);
      expect(find.text('Tổng xuất tháng'), findsOneWidget);
      expect(find.text('Giá trị tồn kho'), findsOneWidget);

      // Kiểm tra Biểu đồ cột tháng này
      expect(find.text('Biểu đồ cột tháng này (kg):'), findsOneWidget);

      // Kiểm tra các cột trong Bảng dữ liệu chi tiết
      expect(find.text('Cột Ngày'), findsWidgets);
      expect(find.text('Cột Mã phiếu'), findsWidgets);
      expect(find.text('Cột Lượng'), findsWidgets);
      expect(find.text('Cột Tiền (₫)'), findsWidgets);

      // Kiểm tra danh sách Top gạo xuất
      expect(find.text('Top gạo xuất nhiều nhất'), findsOneWidget);
    });

    // ----------------------------------------------------
    // MỤC 6: Prototype OCR Quét hóa đơn & Chọn mã lô có sẵn / tạo mới
    // ----------------------------------------------------
    test('Mục 6: OCR trích xuất chính xác 3 mẫu và hỗ trợ chọn mã lô có sẵn / tạo mới', () {
      const ocr = OcrService();
      const suppliers = MockData.suppliers;
      const rices = MockData.rices;

      // Test Mẫu 1
      final res1 = ocr.parseInvoice(
        rawText: OcrService.samples[0].rawText,
        suppliers: suppliers,
        rices: rices,
      );
      expect(res1.matchedSupplierId, 'supplier-lua-viet');
      expect(res1.matchedRiceId, 'rice-st25');
      expect(res1.quantity, 800);
      expect(res1.purchasePrice, 28000);
      expect(res1.batchCode, 'LO-ST25-003');

      // Test Mẫu 2
      final res2 = ocr.parseInvoice(
        rawText: OcrService.samples[1].rawText,
        suppliers: suppliers,
        rices: rices,
      );
      expect(res2.matchedSupplierId, 'supplier-dong-xanh');
      expect(res2.matchedRiceId, 'rice-jasmine');
      expect(res2.quantity, 500);
      expect(res2.purchasePrice, 19500);
      expect(res2.batchCode, 'LO-JAS-002');

      // Test Mẫu 3
      final res3 = ocr.parseInvoice(
        rawText: OcrService.samples[2].rawText,
        suppliers: suppliers,
        rices: rices,
      );
      expect(res3.matchedSupplierId, 'supplier-mekong');
      expect(res3.matchedRiceId, 'rice-brown');
      expect(res3.quantity, 400);
      expect(res3.purchasePrice, 26500);
      expect(res3.batchCode, 'LO-LUT-002');

      // Test nghiệp vụ tạo phiếu nhập cho mã lô có sẵn: cộng dồn số lượng
      final batchProvider = BatchProvider();
      final importProvider = ImportProvider(batchProvider, null);

      final initialStock = batchProvider.totalStockForRice('rice-st25');
      final existingBatch = batchProvider.batches.firstWhere((b) => b.riceId == 'rice-st25');
      final initialBatchQty = existingBatch.quantity;

      // Tạo phiếu nhập bổ sung cho mã lô có sẵn
      final replenishReceipt = ImportReceiptModel(
        id: 'imp-replenish',
        code: 'PN999',
        supplierId: 'supplier-lua-viet',
        supplierName: 'Công ty Lúa Việt',
        date: DateTime.now(),
        riceId: 'rice-st25',
        riceName: 'Gạo ST25',
        quantity: 250,
        purchasePrice: 28000,
        totalAmount: 250 * 28000,
        batchCode: existingBatch.code, // Mã lô có sẵn
        manufactureDate: existingBatch.manufactureDate,
        expiryDate: existingBatch.expiryDate,
      );

      final replenishedBatch = existingBatch.copyWith(
        quantity: 250,
      );

      final success = importProvider.createImportReceipt(
        receipt: replenishReceipt,
        batch: replenishedBatch,
      );

      expect(success, isTrue);
      // Kiểm tra số lượng của lô được cộng dồn chính xác
      final updatedBatch = batchProvider.batches.firstWhere((b) => b.code == existingBatch.code);
      expect(updatedBatch.quantity, initialBatchQty + 250);
      // Tổng tồn kho của gạo tăng đúng 250kg
      expect(batchProvider.totalStockForRice('rice-st25'), initialStock + 250);
    });
  });
}
