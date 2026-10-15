import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_converters.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';

class ImportReceiptMapper implements FirestoreModelMapper<ImportReceiptModel> {
  const ImportReceiptMapper();

  @override
  ImportReceiptModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  ImportReceiptModel fromMap(String id, Map<String, dynamic> data) {
    String riceId = data['riceId'] as String? ?? '';
    String riceName = data['riceName'] as String? ?? data['riceNameSnapshot'] as String? ?? '';
    double quantity = FirestoreFieldCodec.number(data['quantity']);
    double purchasePrice = FirestoreFieldCodec.number(data['purchasePrice'] ?? data['unitPrice']);
    String batchCode = data['batchCode'] as String? ?? '';
    DateTime manufactureDate = FirestoreFieldCodec.dateTime(data['manufactureDate']) ?? DateTime.now();
    DateTime expiryDate = FirestoreFieldCodec.dateTime(data['expiryDate']) ?? DateTime.now();

    final items = data['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty && items.first is Map) {
      final first = items.first as Map<String, dynamic>;
      riceId = first['riceId'] as String? ?? riceId;
      riceName = first['riceNameSnapshot'] as String? ?? first['riceName'] as String? ?? riceName;
      quantity = FirestoreFieldCodec.number(first['quantity'] ?? quantity);
      purchasePrice = FirestoreFieldCodec.number(first['unitPrice'] ?? first['purchasePrice'] ?? purchasePrice);
      batchCode = first['batchCode'] as String? ?? batchCode;
      manufactureDate = FirestoreFieldCodec.dateTime(first['manufactureDate']) ?? manufactureDate;
      expiryDate = FirestoreFieldCodec.dateTime(first['expiryDate']) ?? expiryDate;
    }

    return ImportReceiptModel(
      id: id,
      code: data['code'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? data['supplierNameSnapshot'] as String? ?? '',
      date: FirestoreFieldCodec.dateTime(data['date']) ?? DateTime.now(),
      riceId: riceId,
      riceName: riceName,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalAmount: FirestoreFieldCodec.number(data['totalAmount']),
      batchCode: batchCode,
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
    );
  }

  @override
  Map<String, Object?> toFirestore(
    ImportReceiptModel value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'supplierId': value.supplierId.trim(),
      'supplierName': value.supplierName.trim(),
      'supplierNameSnapshot': value.supplierName.trim(),
      'date': FirestoreFieldCodec.timestamp(value.date),
      'riceId': value.riceId.trim(),
      'riceName': value.riceName.trim(),
      'riceNameSnapshot': value.riceName.trim(),
      'quantity': value.quantity,
      'purchasePrice': value.purchasePrice,
      'totalAmount': value.totalAmount,
      'batchCode': value.batchCode.trim(),
      'manufactureDate': FirestoreFieldCodec.timestamp(value.manufactureDate),
      'expiryDate': FirestoreFieldCodec.timestamp(value.expiryDate),
      'status': 'confirmed',
      'items': [
        {
          'riceId': value.riceId.trim(),
          'riceNameSnapshot': value.riceName.trim(),
          'batchCode': value.batchCode.trim(),
          'quantity': value.quantity,
          'unitPrice': value.purchasePrice,
          'amount': value.totalAmount,
          'manufactureDate': FirestoreFieldCodec.timestamp(value.manufactureDate),
          'expiryDate': FirestoreFieldCodec.timestamp(value.expiryDate),
        }
      ],
    });
  }
}
