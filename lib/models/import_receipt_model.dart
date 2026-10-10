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

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'date': date.toIso8601String(),
        'riceId': riceId,
        'riceName': riceName,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'totalAmount': totalAmount,
        'batchCode': batchCode,
        'manufactureDate': manufactureDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
      };

  factory ImportReceiptModel.fromJson(Map<String, dynamic> json) =>
      ImportReceiptModel(
        id: json['id'] as String,
        code: json['code'] as String,
        supplierId: json['supplierId'] as String,
        supplierName: json['supplierName'] as String,
        date: DateTime.parse(json['date'] as String),
        riceId: json['riceId'] as String,
        riceName: json['riceName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        batchCode: json['batchCode'] as String,
        manufactureDate: DateTime.parse(json['manufactureDate'] as String),
        expiryDate: DateTime.parse(json['expiryDate'] as String),
      );
}
