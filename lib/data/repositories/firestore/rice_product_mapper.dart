import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';

class RiceProductMapper implements FirestoreModelMapper<RiceModel> {
  const RiceProductMapper();

  @override
  RiceModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  RiceModel fromMap(String id, Map<String, dynamic> data) {
    return RiceModel(
      id: id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      unit: data['unit'] as String? ?? 'kg',
      purchasePrice: FirestoreFieldCodec.number(data['purchasePrice']),
      sellingPrice: FirestoreFieldCodec.number(data['sellingPrice']),
      minimumStock: FirestoreFieldCodec.number(data['minimumStock']),
      description: data['description'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      characteristicIds:
          (data['characteristicIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      createdAt: FirestoreFieldCodec.dateTime(data['createdAt']),
      updatedAt: FirestoreFieldCodec.dateTime(data['updatedAt']),
    );
  }

  @override
  Map<String, Object?> toFirestore(RiceModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'name': value.name.trim(),
      'category': value.category.trim(),
      'unit': value.unit.trim(),
      'purchasePrice': value.purchasePrice,
      'sellingPrice': value.sellingPrice,
      'minimumStock': value.minimumStock,
      'description': value.description.trim(),
      'isActive': value.isActive,
      'characteristicIds': value.characteristicIds,
      'createdAt': value.createdAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.createdAt!),
      'updatedAt': value.updatedAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.updatedAt!),
    });
  }
}
