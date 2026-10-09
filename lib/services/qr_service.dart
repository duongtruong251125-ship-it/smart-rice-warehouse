import 'dart:convert';

class QrParsedResult {
  const QrParsedResult({
    required this.rawCode,
    this.batchCode,
    this.batchId,
    this.isValid = true,
    this.metadata,
  });

  final String rawCode;
  final String? batchCode;
  final String? batchId;
  final bool isValid;
  final Map<String, dynamic>? metadata;
}

class QrService {
  /// Giải mã chuỗi QR quét được.
  /// Hỗ trợ cả định dạng thô (ví dụ "LOT-202610-001"), prefix "BATCH:LOT-001",
  /// hoặc JSON: {"batchCode": "...", "batchId": "..."}
  static QrParsedResult parseBatchQr(String rawData) {
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) {
      return const QrParsedResult(rawCode: '', isValid: false);
    }

    // 1. Thử giải mã nếu là JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final code = map['batchCode']?.toString() ?? map['code']?.toString();
        final id = map['batchId']?.toString() ?? map['id']?.toString();
        return QrParsedResult(
          rawCode: trimmed,
          batchCode: code,
          batchId: id,
          isValid: code != null || id != null,
          metadata: map,
        );
      } catch (_) {
        // Parse JSON thất bại thì chuyển sang regex/text
      }
    }

    // 2. Thử tiền tố BATCH: hoặc QR:
    if (trimmed.toUpperCase().startsWith('BATCH:')) {
      final code = trimmed.substring(6).trim();
      return QrParsedResult(
        rawCode: trimmed,
        batchCode: code,
        isValid: code.isNotEmpty,
      );
    }

    // 3. Chuỗi thô là mã lô
    return QrParsedResult(
      rawCode: trimmed,
      batchCode: trimmed,
      isValid: true,
    );
  }

  /// Tạo chuỗi QR chuẩn cho lô hàng (dạng batchCode ổn định)
  static String generateBatchQrPayload({
    required String batchCode,
    String? batchId,
  }) {
    // Để mã QR đơn giản, dễ quét trên mọi camera và thiết bị
    return batchCode;
  }
}
