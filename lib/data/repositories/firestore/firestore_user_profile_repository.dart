import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_paths.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/user_profile_repository.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/user_profile_mapper.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({
    required FirebaseFirestore firestore,
    this.mapper = const UserProfileMapper(),
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final UserProfileMapper mapper;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  @override
  Stream<List<UserModel>> watchAll() {
    return _users
        .orderBy('displayName')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.docs
            .map((document) => mapper.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  @override
  Stream<UserModel?> watchById(String uid) {
    return _users
        .doc(_validateUid(uid))
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.exists
            ? mapper.fromMap(snapshot.id, snapshot.data() ?? const {})
            : null);
  }

  @override
  Future<UserModel?> getById(String uid) async {
    try {
      final snapshot = await _users
          .doc(_validateUid(uid))
          .get(const GetOptions(source: Source.server));
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        throw const RepositoryException('Hồ sơ chưa được máy chủ xác nhận.',
            code: 'unverified-profile');
      }
      if (!snapshot.exists) return null;
      return mapper.fromMap(snapshot.id, snapshot.data() ?? const {});
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> createPendingProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    try {
      await _users.doc(_validateUid(uid)).set({
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'role': 'staff',
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    try {
      await _users.doc(_validateUid(uid)).update({
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> updateAccess({
    required String uid,
    required String role,
    required bool isActive,
  }) async {
    if (role != 'admin' && role != 'staff') {
      throw ArgumentError.value(role, 'role', 'Role must be admin or staff.');
    }
    try {
      await _users.doc(_validateUid(uid)).update({
        'role': role,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  String _validateUid(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(uid, 'uid', 'Invalid Firebase user ID.');
    }
    return normalized;
  }

  RepositoryException _mapException(FirebaseException error) {
    String message = error.message ?? 'Không thể truy cập hồ sơ người dùng.';
    if (error.code == 'permission-denied') {
      message = 'Bạn không có quyền cập nhật thông tin này trên máy chủ.';
    } else if (error.code == 'not-found') {
      message = 'Hồ sơ người dùng không tồn tại trên hệ thống.';
    } else if (error.code == 'unavailable') {
      message =
          'Máy chủ Firestore tạm thời không phản hồi. Vui lòng thử lại sau.';
    }
    return RepositoryException(
      message,
      code: error.code,
      cause: error,
    );
  }
}
