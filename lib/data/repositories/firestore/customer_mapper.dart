import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';

class CustomerMapper implements FirestoreModelMapper<CustomerModel> {
  const CustomerMapper();

  @override
  CustomerModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  CustomerModel fromMap(String id, Map<String, dynamic> data) {
    CustomerType type = CustomerType.retail;
    final typeStr = data['customerType'] as String?;
    if (typeStr != null) {
      try {
        type = CustomerType.values.byName(typeStr);
      } catch (_) {
        type = CustomerType.retail;
      }
    }

    return CustomerModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      customerType: type,
      address: data['address'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      email: data['email'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdAt: FirestoreFieldCodec.dateTime(data['createdAt']),
      updatedAt: FirestoreFieldCodec.dateTime(data['updatedAt']),
    );
  }

  @override
  Map<String, Object?> toFirestore(CustomerModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'name': value.name.trim(),
      'phone': value.phone.trim(),
      'customerType': value.customerType.name,
      'address': value.address.trim(),
      'isActive': value.isActive,
      'email': value.email.trim(),
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
