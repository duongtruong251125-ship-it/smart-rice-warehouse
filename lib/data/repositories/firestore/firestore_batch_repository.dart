import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/batch_mapper.dart';
import 'package:smart_rice_warehouse/data/repositories/firestore/firestore_collection_repository.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/batch_location_writer.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/contracts/repositories/repository_exception.dart';

class FirestoreBatchRepository extends FirestoreCollectionRepository<BatchModel>
    implements BatchLocationWriter {
  FirestoreBatchRepository({required super.firestore, super.syncPolicy})
      : _firestore = firestore,
        super(
            collectionPath: 'batches',
            mapper: const BatchMapper(),
            orderByField: 'code',
            manageTimestamps: true);

  final FirebaseFirestore _firestore;

  @override
  Future<void> moveBatch({
    required String batchId,
    required String locationId,
    required String locationName,
  }) async {
    try {
      await _firestore.collection('batches').doc(batchId).update({
        'warehouseLocationId': locationId,
        'locationName': locationName,
        'locationNameSnapshot': locationName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw RepositoryException(
          error.message ?? 'Không thể chuyển vị trí trên máy chủ.',
          code: error.code,
          cause: error);
    }
  }
}
