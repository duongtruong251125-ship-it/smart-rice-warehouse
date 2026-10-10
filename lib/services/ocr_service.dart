import 'package:smart_rice_warehouse/models/ocr_invoice_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';

class OcrSampleInvoice {
  const OcrSampleInvoice({
    required this.title,
    required this.rawText,
  });

  final String title;
  final String rawText;
}

class OcrService {
  const OcrService();

  static const List<OcrSampleInvoice> samples = [
    OcrSampleInvoice(
      title: 'Hóa đơn Cty Lúa Việt (ST25)',
      rawText: '''
CÔNG TY LÚA VIỆT
HÓA ĐƠN NHẬP KHO NÔNG SẢN
Số HĐ: HD-2026-9901
Ngày giao: 05/10/2026
Mã lô: LO-ST25-003
Tên hàng hóa: Gạo ST25 (Gạo thơm cao cấp)
Số lượng: 800 kg
Đơn giá: 28.000 VNĐ/kg
Thành tiền: 22.400.000 VNĐ
Ngày sản xuất: 01/10/2026
Hạn sử dụng: 01/10/2027
Đại diện giao hàng: Nguyễn Văn A
''',
    ),
    OcrSampleInvoice(
      title: 'Phiếu giao hàng Cty Đồng Xanh (Jasmine)',
      rawText: '''
CÔNG TY ĐỒNG XANH
PHIẾU GIAO HÀNG & CHỨNG NHẬN CHẤT LƯỢNG
Ngày: 06/10/2026
Nhà cung cấp: Công ty Đồng Xanh
Sản phẩm: Gạo Jasmine
Quy cách: Đóng bao 50kg
Số lượng: 500 kg
Đơn giá nhập: 19.500 đ
Tổng tiền: 9.750.000 đ
Số lô sản xuất: LO-JAS-002
NSX: 20/09/2026
HSD: 20/09/2027
''',
    ),
    OcrSampleInvoice(
      title: 'Hóa đơn Nông sản Mekong (Gạo lứt)',
      rawText: '''
NÔNG SẢN MEKONG
HÓA ĐƠN BÁN HÀNG
Ngày lập: 07/10/2026
Khách hàng: Kho gạo Thông minh
Đơn vị bán: Nông sản Mekong
Mặt hàng: Gạo lứt dinh dưỡng
Mã lô: LO-LUT-002
Khối lượng: 400 kg
Giá mua: 26.500 VNĐ/kg
Tổng cộng: 10.600.000 VNĐ
NSX: 25/09/2026
HSD: 25/03/2027
''',
    ),
  ];

  /// Trích xuất các trường thông tin từ văn bản hóa đơn OCR
  OcrExtractedInvoice parseInvoice({
    required String rawText,
    required List<SupplierModel> suppliers,
    required List<RiceModel> rices,
  }) {
    final lowerText = rawText.toLowerCase();

    // 1. Nhận diện Nhà cung cấp (Supplier)
    String? matchedSupplierName;
    String? matchedSupplierId;

    for (final supplier in suppliers) {
      final nameLower = supplier.name.toLowerCase();
      if (lowerText.contains(nameLower) ||
          lowerText.contains(nameLower.replaceAll('công ty', '').trim())) {
        matchedSupplierName = supplier.name;
        matchedSupplierId = supplier.id;
        break;
      }
    }

    // 2. Nhận diện Loại gạo (Rice)
    String? matchedRiceName;
    String? matchedRiceId;

    for (final rice in rices) {
      final nameLower = rice.name.toLowerCase();
      final codeLower = rice.code.toLowerCase();
      if (lowerText.contains(nameLower) ||
          lowerText.contains(codeLower) ||
          lowerText.contains(nameLower.replaceAll('gạo', '').trim())) {
        matchedRiceName = rice.name;
        matchedRiceId = rice.id;
        break;
      }
    }

    // 3. Nhận diện Số lượng (Quantity)
    double? quantity;
    final explicitQtyRegex = RegExp(
      r'(?:số\s*lượng|khối\s*lượng|sl|qty)\s*[:.]?\s*(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    );
    final explicitQtyMatch = explicitQtyRegex.firstMatch(rawText);
    if (explicitQtyMatch != null) {
      final numStr = explicitQtyMatch.group(1)?.replaceAll(',', '.') ?? '';
      quantity = double.tryParse(numStr);
    }

    if (quantity == null) {
      final fallbackQty = RegExp(r'(\d+(?:[.,]\d+)?)\s*kg', caseSensitive: false).firstMatch(rawText);
      if (fallbackQty != null) {
        quantity = double.tryParse(fallbackQty.group(1)?.replaceAll(',', '.') ?? '');
      }
    }

    // 4. Nhận diện Đơn giá (Purchase price)
    double? unitPrice;
    final priceRegex = RegExp(
      r'(?:đơn\s*giá|giá\s*nhập|giá\s*mua|giá)\s*[:.]?\s*(\d{1,3}(?:\.\d{3})+|\d+)',
      caseSensitive: false,
    );
    final priceMatch = priceRegex.firstMatch(rawText);
    if (priceMatch != null) {
      final numStr = priceMatch.group(1)?.replaceAll('.', '') ?? '';
      unitPrice = double.tryParse(numStr);
    }
    if (unitPrice == null) {
      final fallbackPrice = RegExp(
        r'(\d{1,3}(?:\.\d{3})+|\d+)\s*(?:vnđ|vnd|đ|\/kg)',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (fallbackPrice != null) {
        final numStr = fallbackPrice.group(1)?.replaceAll('.', '') ?? '';
        unitPrice = double.tryParse(numStr);
      }
    }

    // 5. Nhận diện Mã lô (Batch Code)
    String? batchCode;
    final explicitBatchRegex = RegExp(
      r'(?:lô|mã\s*lô|số\s*lô|lot|batch)\s*(?:sản\s*xuất)?\s*[:.]?\s*([A-Z0-9\-]+)',
      caseSensitive: false,
    );
    final explicitBatchMatch = explicitBatchRegex.firstMatch(rawText);
    if (explicitBatchMatch != null) {
      batchCode = explicitBatchMatch.group(1)?.trim().toUpperCase();
    }
    if (batchCode == null) {
      final fallbackBatch = RegExp(
        r'LO-[A-Z0-9]{2,5}-[0-9]{3}',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (fallbackBatch != null) {
        batchCode = fallbackBatch.group(0)?.toUpperCase();
      }
    }

    // 6. Nhận diện Ngày tháng (Invoice date, NSX, HSD)
    final allDates = _extractDates(rawText);
    DateTime? invoiceDate = allDates.isNotEmpty ? allDates.first : null;
    DateTime? manufactureDate;
    DateTime? expiryDate;

    // Tìm riêng NSX và HSD (bắt buộc có prefix)
    final nsxRegex = RegExp(
      r'(?:nsx|ngày\s*sản\s*xuất|sản\s*xuất)\s*[:.]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4})',
      caseSensitive: false,
    );
    final nsxMatch = nsxRegex.firstMatch(rawText);
    if (nsxMatch != null) {
      manufactureDate = _parseDateString(nsxMatch.group(1) ?? '');
    }

    final hsdRegex = RegExp(
      r'(?:hsd|hạn\s*sử\s*dụng|hết\s*hạn)\s*[:.]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4})',
      caseSensitive: false,
    );
    final hsdMatch = hsdRegex.firstMatch(rawText);
    if (hsdMatch != null) {
      expiryDate = _parseDateString(hsdMatch.group(1) ?? '');
    }

    return OcrExtractedInvoice(
      supplierName: matchedSupplierName,
      matchedSupplierId: matchedSupplierId,
      riceName: matchedRiceName,
      matchedRiceId: matchedRiceId,
      quantity: quantity,
      purchasePrice: unitPrice,
      date: invoiceDate ?? DateTime.now(),
      batchCode: batchCode,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
      rawText: rawText,
      confidence: 0.94,
    );
  }

  List<DateTime> _extractDates(String text) {
    final dateRegex = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})');
    final matches = dateRegex.allMatches(text);
    final dates = <DateTime>[];

    for (final match in matches) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final year = int.tryParse(match.group(3) ?? '');
      if (day != null && month != null && year != null) {
        try {
          dates.add(DateTime(year, month, day));
        } catch (_) {}
      }
    }
    return dates;
  }

  DateTime? _parseDateString(String dateStr) {
    final parts = dateStr.split(RegExp(r'[\/\-\.]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }
    }
    return null;
  }
}
