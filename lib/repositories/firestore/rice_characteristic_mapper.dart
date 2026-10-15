import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_converters.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';

class RiceCharacteristicMapper
    implements FirestoreModelMapper<RiceCharacteristicModel> {
  const RiceCharacteristicMapper();

  @override
  RiceCharacteristicModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  RiceCharacteristicModel fromMap(String id, Map<String, dynamic> data) {
    return RiceCharacteristicModel(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFF0D9488,
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: FirestoreFieldCodec.dateTime(data['createdAt']),
      updatedAt: FirestoreFieldCodec.dateTime(data['updatedAt']),
    );
  }

  @override
  Map<String, Object?> toFirestore(
    RiceCharacteristicModel value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'name': value.name.trim(),
      'description': value.description.trim(),
      'colorValue': value.colorValue,
      'isDefault': value.isDefault,
      'createdAt': value.createdAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.createdAt!),
      'updatedAt': value.updatedAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.updatedAt!),
    });
  }
}
