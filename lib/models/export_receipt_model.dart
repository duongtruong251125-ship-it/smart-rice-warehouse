import 'package:smart_rice_warehouse/models/batch_allocation_model.dart';

class ExportReceiptModel {
  const ExportReceiptModel({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.riceId,
    required this.riceName,
    required this.quantity,
    required this.sellingPrice,
    required this.totalAmount,
    required this.note,
    this.allocations = const <BatchAllocation>[],
  });

  final String id;
  final String code;
  final String customerId;
  final String customerName;
  final DateTime date;
  final String riceId;
  final String riceName;
  final double quantity;
  final double sellingPrice;
  final double totalAmount;
  final String note;
  final List<BatchAllocation> allocations;

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'customerId': customerId,
        'customerName': customerName,
        'date': date.toIso8601String(),
        'riceId': riceId,
        'riceName': riceName,
        'quantity': quantity,
        'sellingPrice': sellingPrice,
        'totalAmount': totalAmount,
        'note': note,
        'allocations': allocations.map((item) => item.toMap()).toList(),
      };

  factory ExportReceiptModel.fromJson(Map<String, dynamic> json) =>
      ExportReceiptModel(
        id: json['id'] as String,
        code: json['code'] as String,
        customerId: json['customerId'] as String,
        customerName: json['customerName'] as String,
        date: DateTime.parse(json['date'] as String),
        riceId: json['riceId'] as String,
        riceName: json['riceName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        note: json['note'] as String,
        allocations: (json['allocations'] as List<dynamic>? ?? const [])
            .map((item) =>
                BatchAllocation.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}
