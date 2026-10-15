import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_converters.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';

class WarehouseLocationMapper
    implements FirestoreModelMapper<WarehouseLocationModel> {
  const WarehouseLocationMapper();

  @override
  WarehouseLocationModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  WarehouseLocationModel fromMap(String id, Map<String, dynamic> data) {
    return WarehouseLocationModel(
      id: id,
      zone: data['zone'] as String? ?? '',
      rack: data['rack'] as String? ?? '',
      shelf: data['shelf'] as String? ?? '',
      code: data['code'] as String? ?? '',
      capacity: FirestoreFieldCodec.number(data['capacity']),
      currentBatchCount: (data['currentBatchCount'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
    );
  }

  @override
  Map<String, Object?> toFirestore(
      WarehouseLocationModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'zone': value.zone.trim(),
      'rack': value.rack.trim(),
      'shelf': value.shelf.trim(),
      'code': value.code.trim(),
      'capacity': value.capacity,
      'currentBatchCount': value.currentBatchCount,
      'isActive': value.isActive,
      'description': value.description?.trim(),
    });
  }
}
