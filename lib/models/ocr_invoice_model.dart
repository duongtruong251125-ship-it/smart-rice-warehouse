class OcrExtractedInvoice {
  OcrExtractedInvoice({
    this.supplierName,
    this.matchedSupplierId,
    this.riceName,
    this.matchedRiceId,
    this.quantity,
    this.purchasePrice,
    this.date,
    this.batchCode,
    this.manufactureDate,
    this.expiryDate,
    required this.rawText,
    this.confidence = 0.92,
  });

  String? supplierName;
  String? matchedSupplierId;
  String? riceName;
  String? matchedRiceId;
  double? quantity;
  double? purchasePrice;
  DateTime? date;
  String? batchCode;
  DateTime? manufactureDate;
  DateTime? expiryDate;
  final String rawText;
  final double confidence;

  double get totalAmount => (quantity ?? 0) * (purchasePrice ?? 0);
}
