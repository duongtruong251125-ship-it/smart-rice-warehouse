class ImportReceiptModel {
  const ImportReceiptModel({
    required this.id,
    required this.code,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    required this.riceId,
    required this.riceName,
    required this.quantity,
    required this.purchasePrice,
    required this.totalAmount,
    required this.batchCode,
    required this.manufactureDate,
    required this.expiryDate,
  });

  final String id;
  final String code;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final String riceId;
  final String riceName;
  final double quantity;
  final double purchasePrice;
  final double totalAmount;
  final String batchCode;
  final DateTime manufactureDate;
  final DateTime expiryDate;
}
