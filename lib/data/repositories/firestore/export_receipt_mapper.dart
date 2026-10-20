import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/batch_allocation_model.dart';
import 'package:smart_rice_warehouse/logic/models/export_receipt_model.dart';

class ExportReceiptMapper implements FirestoreModelMapper<ExportReceiptModel> {
  const ExportReceiptMapper();

  @override
  ExportReceiptModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  ExportReceiptModel fromMap(String id, Map<String, dynamic> data) {
    String riceId = data['riceId'] as String? ?? '';
    String riceName = data['riceName'] as String? ??
        data['riceNameSnapshot'] as String? ??
        '';
    double quantity = FirestoreFieldCodec.number(data['quantity']);
    double sellingPrice =
        FirestoreFieldCodec.number(data['sellingPrice'] ?? data['unitPrice']);

    final items = data['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty && items.first is Map) {
      final first = items.first as Map<String, dynamic>;
      riceId = first['riceId'] as String? ?? riceId;
      riceName = first['riceNameSnapshot'] as String? ??
          first['riceName'] as String? ??
          riceName;
      quantity = FirestoreFieldCodec.number(first['quantity'] ?? quantity);
      sellingPrice = FirestoreFieldCodec.number(
          first['unitPrice'] ?? first['sellingPrice'] ?? sellingPrice);
    }

    final rawAllocations = data['allocations'] as List<dynamic>? ?? const [];
    final allocations = rawAllocations
        .whereType<Map<String, dynamic>>()
        .map((map) => BatchAllocation.fromMap(map))
        .toList(growable: false);

    return ExportReceiptModel(
      id: id,
      code: data['code'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ??
          data['customerNameSnapshot'] as String? ??
          '',
      date: FirestoreFieldCodec.dateTime(data['date']) ?? DateTime.now(),
      riceId: riceId,
      riceName: riceName,
      quantity: quantity,
      sellingPrice: sellingPrice,
      totalAmount: FirestoreFieldCodec.number(data['totalAmount']),
      note: data['note'] as String? ?? '',
      allocations: allocations,
    );
  }

  @override
  Map<String, Object?> toFirestore(
    ExportReceiptModel value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'customerId': value.customerId.trim(),
      'customerName': value.customerName.trim(),
      'customerNameSnapshot': value.customerName.trim(),
      'date': FirestoreFieldCodec.timestamp(value.date),
      'riceId': value.riceId.trim(),
      'riceName': value.riceName.trim(),
      'riceNameSnapshot': value.riceName.trim(),
      'quantity': value.quantity,
      'sellingPrice': value.sellingPrice,
      'totalAmount': value.totalAmount,
      'note': value.note.trim(),
      'status': 'confirmed',
      'allocations': value.allocations.map((a) => a.toMap()).toList(),
      'items': [
        {
          'riceId': value.riceId.trim(),
          'riceNameSnapshot': value.riceName.trim(),
          'quantity': value.quantity,
          'unitPrice': value.sellingPrice,
          'amount': value.totalAmount,
          'allocations': value.allocations.map((a) => a.toMap()).toList(),
        }
      ],
    });
  }
}
