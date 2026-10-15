import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_converters.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';

class BatchMapper implements FirestoreModelMapper<BatchModel> {
  const BatchMapper();

  @override
  BatchModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  BatchModel fromMap(String id, Map<String, dynamic> data) {
    BatchStatus status = BatchStatus.available;
    final statusStr = data['status'] as String?;
    if (statusStr != null) {
      try {
        status = BatchStatus.values.byName(statusStr);
      } catch (_) {
        status = BatchStatus.available;
      }
    }

    return BatchModel(
      id: id,
      code: data['code'] as String? ?? '',
      riceId: data['riceId'] as String? ?? '',
      riceName: data['riceName'] as String? ?? data['riceNameSnapshot'] as String? ?? '',
      quantity: FirestoreFieldCodec.number(data['remainingQuantity'] ?? data['quantity']),
      importDate: FirestoreFieldCodec.dateTime(data['importDate']) ?? DateTime.now(),
      manufactureDate: FirestoreFieldCodec.dateTime(data['manufactureDate']) ?? DateTime.now(),
      expiryDate: FirestoreFieldCodec.dateTime(data['expiryDate']) ?? DateTime.now(),
      status: status,
      supplierId: data['supplierId'] as String?,
      supplierName: data['supplierName'] as String? ?? data['supplierNameSnapshot'] as String?,
      warehouseLocationId: data['warehouseLocationId'] as String?,
      locationName: data['locationName'] as String? ?? data['locationNameSnapshot'] as String?,
    );
  }

  @override
  Map<String, Object?> toFirestore(BatchModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'riceId': value.riceId.trim(),
      'riceName': value.riceName.trim(),
      'riceNameSnapshot': value.riceName.trim(),
      'quantity': value.quantity,
      'remainingQuantity': value.quantity,
      'importDate': FirestoreFieldCodec.timestamp(value.importDate),
      'manufactureDate': FirestoreFieldCodec.timestamp(value.manufactureDate),
      'expiryDate': FirestoreFieldCodec.timestamp(value.expiryDate),
      'status': value.status.name,
      'supplierId': value.supplierId?.trim(),
      'supplierName': value.supplierName?.trim(),
      'supplierNameSnapshot': value.supplierName?.trim(),
      'warehouseLocationId': value.warehouseLocationId?.trim(),
      'locationName': value.locationName?.trim(),
      'locationNameSnapshot': value.locationName?.trim(),
    });
  }
}
