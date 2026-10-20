import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/data/firebase/firebase_auth_service.dart';
import 'package:smart_rice_warehouse/data/firebase/business_sync_policy.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/restarting_repository_stream.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/crud_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';

/// Reusable Firestore CRUD implementation for simple collections.
///
/// Inventory-changing operations must not use these generic write methods.
/// They will use dedicated transaction repositories in later migration tasks.
class FirestoreCollectionRepository<T> implements CrudRepository<T> {
  FirestoreCollectionRepository({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required FirestoreModelMapper<T> mapper,
    this.orderByField,
    this.manageTimestamps = false,
    this.syncPolicy,
    this.authChanges,
  })  : _firestore = firestore,
        _collectionPath = collectionPath,
        _mapper = mapper;

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  final FirestoreModelMapper<T> _mapper;
  final String? orderByField;
  final bool manageTimestamps;
  final BusinessSyncPolicy? syncPolicy;
  final Stream<AuthenticatedUser?>? authChanges;

  Stream<R> _watch<R>(Stream<R> Function() open) => restartingRepositoryStream(
        open: open,
        reconnect: authChanges ??
            (FirebaseAuthService.instance.isInitialized
                ? FirebaseAuthService.instance.authStateChanges
                : null),
        policyChanges: syncPolicy,
        shouldListen: () => syncPolicy?.shouldListen ?? true,
        mapError: (error) => error is FirebaseException
            ? _mapFirebaseException(error)
            : error is RepositoryException
                ? error
                : RepositoryException('Dữ liệu đồng bộ không hợp lệ: $error',
                    code: 'invalid-data', cause: error),
      );

  CollectionReference<T> get collection =>
      _firestore.collection(_collectionPath).withConverter<T>(
            fromFirestore: _mapper.fromFirestore,
            toFirestore: _mapper.toFirestore,
          );

  @override
  Stream<List<T>> watchAll() {
    final Query<T> query =
        orderByField == null ? collection : collection.orderBy(orderByField!);
    return _watch(() => query
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.docs
            .map((document) => document.data())
            .toList(growable: false)));
  }

  @override
  Stream<T?> watchById(String id) {
    final docRef = collection.doc(_validateId(id));
    return _watch(() => docRef
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.data()));
  }

  @override
  Future<List<T>> getAll() async {
    try {
      final Query<T> query =
          orderByField == null ? collection : collection.orderBy(orderByField!);
      final snapshot = await query.get(const GetOptions(source: Source.server));
      return snapshot.docs.map((document) => document.data()).toList(
            growable: false,
          );
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<T?> getById(String id) async {
    try {
      final snapshot = await collection.doc(_validateId(id)).get();
      return snapshot.data();
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> create(String id, T value) async {
    try {
      if (!manageTimestamps) {
        await collection.doc(_validateId(id)).set(value);
        return;
      }
      final data = _mapper.toFirestore(value, null)
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(_collectionPath)
          .doc(_validateId(id))
          .set(data);
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> update(String id, T value) async {
    try {
      final data = _mapper.toFirestore(value, null);
      if (manageTimestamps) {
        data.remove('createdAt');
        data['updatedAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection(_collectionPath).doc(_validateId(id)).update(
            data,
          );
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await collection.doc(_validateId(id)).delete();
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  String _validateId(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        id,
        'id',
        'Firestore document ID must be non-empty and must not contain a slash.',
      );
    }
    return normalized;
  }

  RepositoryException _mapFirebaseException(FirebaseException error) {
    return RepositoryException(
      error.message ?? 'Không thể truy cập dữ liệu trực tuyến.',
      code: error.code,
      cause: error,
    );
  }
}
