import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/core/firebase/firestore_converters.dart';
import 'package:smart_rice_warehouse/repositories/contracts/crud_repository.dart';
import 'package:smart_rice_warehouse/repositories/contracts/repository_exception.dart';

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
  })  : _firestore = firestore,
        _collectionPath = collectionPath,
        _mapper = mapper;

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  final FirestoreModelMapper<T> _mapper;
  final String? orderByField;
  final bool manageTimestamps;

  CollectionReference<T> get collection =>
      _firestore.collection(_collectionPath).withConverter<T>(
            fromFirestore: _mapper.fromFirestore,
            toFirestore: _mapper.toFirestore,
          );

  @override
  Stream<List<T>> watchAll() {
    final Query<T> query = orderByField == null
        ? collection
        : collection.orderBy(orderByField!);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map((document) => document.data()).toList(
                growable: false,
              ),
        );
  }

  @override
  Stream<T?> watchById(String id) {
    return collection.doc(_validateId(id)).snapshots().map(
          (snapshot) => snapshot.data(),
        );
  }

  @override
  Future<List<T>> getAll() async {
    try {
      final Query<T> query = orderByField == null
          ? collection
          : collection.orderBy(orderByField!);
      final snapshot = await query.get();
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
      await _firestore.collection(_collectionPath).doc(_validateId(id)).set(data);
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
