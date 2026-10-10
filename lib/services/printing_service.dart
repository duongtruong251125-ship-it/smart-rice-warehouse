import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';

abstract final class PrintingService {
  static Future<bool> printBatchLabel(BatchModel batch) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
            100 * PdfPageFormat.mm, 70 * PdfPageFormat.mm,
            marginAll: 6 * PdfPageFormat.mm),
        build: (_) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: batch.code,
              width: 45 * PdfPageFormat.mm,
              height: 45 * PdfPageFormat.mm,
            ),
            pw.SizedBox(width: 5 * PdfPageFormat.mm),
            pw.Expanded(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SMART RICE WAREHOUSE',
                      style:
                          const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Batch: ${batch.code}',
                      style: const pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rice: ${_ascii(batch.riceName)}'),
                  pw.Text('Weight: ${batch.quantity.toStringAsFixed(1)} kg'),
                  pw.Text('Expiry: ${_date(batch.expiryDate)}'),
                  pw.Text(
                      'Location: ${_ascii(batch.locationName ?? 'Unassigned')}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Printing.layoutPdf(
      name: 'batch-${batch.code}.pdf',
      onLayout: (_) => document.save(),
    );
  }

  static Future<bool> printWeightReceipt({
    required String riceName,
    required String supplierName,
    required double quantity,
    required double moisture,
    required double impurity,
    required double totalAmount,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SMART RICE WAREHOUSE',
                style: const pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('WEIGHT RECEIPT'),
            pw.Divider(),
            pw.Text('Rice: ${_ascii(riceName)}'),
            pw.Text('Supplier: ${_ascii(supplierName)}'),
            pw.Text('Weight: ${quantity.toStringAsFixed(2)} kg'),
            pw.Text('Moisture: ${moisture.toStringAsFixed(2)}%'),
            pw.Text('Impurity: ${impurity.toStringAsFixed(2)}%'),
            pw.Text('Total: ${totalAmount.toStringAsFixed(0)} VND'),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Warehouse staff'), pw.Text('Supplier')],
            ),
          ],
        ),
      ),
    );
    return Printing.layoutPdf(
      name: 'weight-receipt.pdf',
      onLayout: (_) => document.save(),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _ascii(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final result = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final index = source.indexOf(character);
      result.write(index < 0 ? character : target[index]);
    }
    return result.toString();
  }
}
