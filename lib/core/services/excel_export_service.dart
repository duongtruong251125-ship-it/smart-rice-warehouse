import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class ExcelExportService {
  static Uint8List buildInventoryReport(
    List<BatchModel> batches,
    List<RiceModel> rices,
  ) {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'TonKho_FEFO';

    // Tiêu đề lớn
    sheet.getRangeByName('A1:J1').merge();
    final xlsio.Range headerTitle = sheet.getRangeByName('A1');
    headerTitle.setText('BÁO CÁO TỒN KHO & LÔ HÀNG FEFO');
    headerTitle.cellStyle.fontSize = 16;
    headerTitle.cellStyle.bold = true;
    headerTitle.cellStyle.hAlign = xlsio.HAlignType.center;

    // Header bảng
    final headers = [
      'Mã Lô',
      'Tên Gạo',
      'SL (Kg)',
      'SL (Bao)',
      'Vị trí',
      'Ngày Nhập',
      'Hạn SD',
      'Trạng Thái',
      'Giá vốn (VNĐ)',
      'Giá trị tồn (VNĐ)',
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#16A36A'; // AppTheme primary
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int rowIndex = 4;
    double totalKg = 0;
    double totalValue = 0;
    final now = DateTime.now();
    final pricesByRiceId = {
      for (final rice in rices) rice.id: rice.purchasePrice,
    };

    for (var batch in batches) {
      final bags = batch.quantity / 50;
      final purchasePrice = pricesByRiceId[batch.riceId] ?? 0;
      final inventoryValue = batch.quantity * purchasePrice;
      totalKg += batch.quantity;
      totalValue += inventoryValue;

      sheet.getRangeByIndex(rowIndex, 1).setText(batch.code);
      sheet.getRangeByIndex(rowIndex, 2).setText(batch.riceName);
      sheet.getRangeByIndex(rowIndex, 3).setNumber(batch.quantity);
      sheet.getRangeByIndex(rowIndex, 4).setNumber(bags);
      sheet.getRangeByIndex(rowIndex, 5).setText(batch.locationName ?? '');
      sheet
          .getRangeByIndex(rowIndex, 6)
          .setText(DateFormatter.ddMMyyyy(batch.importDate));
      sheet
          .getRangeByIndex(rowIndex, 7)
          .setText(DateFormatter.ddMMyyyy(batch.expiryDate));

      final cellStatus = sheet.getRangeByIndex(rowIndex, 8);
      cellStatus.setText(batch.status.label);
      sheet.getRangeByIndex(rowIndex, 9).setNumber(purchasePrice);
      sheet.getRangeByIndex(rowIndex, 10).setNumber(inventoryValue);

      final daysUntilExpiry = batch.expiryDate.difference(now).inDays;
      if (daysUntilExpiry <= 7) {
        cellStatus.cellStyle.backColor = '#D94A45'; // Danger
        cellStatus.cellStyle.fontColor = '#FFFFFF';
      } else if (daysUntilExpiry <= 30) {
        cellStatus.cellStyle.backColor = '#F2A526'; // Warning
      }

      rowIndex++;
    }

    // Tổng cộng
    sheet.getRangeByIndex(rowIndex, 1).setText('TỔNG CỘNG');
    sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 3).setNumber(totalKg);
    sheet.getRangeByIndex(rowIndex, 3).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 10).setNumber(totalValue);
    sheet.getRangeByIndex(rowIndex, 10).cellStyle.bold = true;

    // Căn chỉnh độ rộng
    for (int i = 1; i <= 10; i++) {
      sheet.autoFitColumn(i);
    }

    final bytes = Uint8List.fromList(workbook.saveAsStream());
    workbook.dispose();
    return bytes;
  }

  static Future<void> exportInventoryReport(
    List<BatchModel> batches,
    List<RiceModel> rices,
  ) async {
    final bytes = buildInventoryReport(batches, rices);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: const ['BaoCaoTonKho.xlsx'],
        subject: 'Báo cáo tồn kho Smart Rice Warehouse',
      ),
    );
  }
}
