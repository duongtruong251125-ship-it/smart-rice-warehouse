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
}
