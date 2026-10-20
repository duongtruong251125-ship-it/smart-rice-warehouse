import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';

class UserProfileMapper implements FirestoreModelMapper<UserModel> {
  const UserProfileMapper();

  @override
  UserModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  UserModel fromMap(String uid, Map<String, dynamic> data) {
    final role = data['role'];
    if (role is! String || !const ['admin', 'staff'].contains(role)) {
      throw const RepositoryException('Hồ sơ phân quyền không hợp lệ.',
          code: 'invalid-profile-role');
    }
    if (data['isActive'] is! bool) {
      throw const RepositoryException('Dữ liệu hồ sơ tài khoản không hợp lệ.',
          code: 'invalid-profile-data');
    }
    return UserModel(
      id: uid,
      name: (data['displayName'] as String? ?? '').trim(),
      email: (data['email'] as String? ?? '').trim().toLowerCase(),
      role: role,
      isActive: data['isActive'] as bool,
      createdAt: FirestoreFieldCodec.dateTime(data['createdAt']),
      updatedAt: FirestoreFieldCodec.dateTime(data['updatedAt']),
    );
  }

  @override
  Map<String, Object?> toFirestore(UserModel value, SetOptions? options) {
    return FirestoreFieldCodec.withoutNullValues({
      'email': value.email.trim().toLowerCase(),
      'displayName': value.name.trim(),
      'role': value.role,
      'isActive': value.isActive,
      'createdAt': value.createdAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.createdAt!),
      'updatedAt': value.updatedAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.updatedAt!),
    });
  }
}
