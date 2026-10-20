import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';

class SupplierMapper implements FirestoreModelMapper<SupplierModel> {
  const SupplierMapper();

  @override
  SupplierModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  SupplierModel fromMap(String id, Map<String, dynamic> data) {
    return SupplierModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      taxCode: data['taxCode'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      note: data['note'] as String? ?? '',
      createdAt: FirestoreFieldCodec.dateTime(data['createdAt']),
      updatedAt: FirestoreFieldCodec.dateTime(data['updatedAt']),
    );
  }

  @override
  Map<String, Object?> toFirestore(SupplierModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'name': value.name.trim(),
      'phone': value.phone.trim(),
      'email': value.email.trim(),
      'address': value.address.trim(),
      'taxCode': value.taxCode.trim(),
      'isActive': value.isActive,
      'note': value.note.trim(),
      'createdAt': value.createdAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.createdAt!),
      'updatedAt': value.updatedAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.updatedAt!),
    });
  }
}
