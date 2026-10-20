import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/stock_movement_model.dart';

class StockMovementMapper implements FirestoreModelMapper<StockMovementModel> {
  const StockMovementMapper();

  @override
  StockMovementModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  StockMovementModel fromMap(String id, Map<String, dynamic> data) {
    return StockMovementModel(
      id: id,
      type: data['type'] as String? ?? 'adjustment',
      batchId: data['batchId'] as String? ?? '',
      riceId: data['riceId'] as String? ?? '',
      quantityDelta: FirestoreFieldCodec.number(data['quantityDelta']),
      quantityBefore: FirestoreFieldCodec.number(data['quantityBefore']),
      quantityAfter: FirestoreFieldCodec.number(data['quantityAfter']),
      referenceType: data['referenceType'] as String? ?? '',
      referenceId: data['referenceId'] as String? ?? '',
      performedBy: data['performedBy'] as String? ?? 'system',
      createdAt:
          FirestoreFieldCodec.dateTime(data['createdAt']) ?? DateTime.now(),
      note: data['note'] as String? ?? '',
    );
  }

  @override
  Map<String, Object?> toFirestore(
    StockMovementModel value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'type': value.type,
      'batchId': value.batchId,
      'riceId': value.riceId,
      'quantityDelta': value.quantityDelta,
      'quantityBefore': value.quantityBefore,
      'quantityAfter': value.quantityAfter,
      'referenceType': value.referenceType,
      'referenceId': value.referenceId,
      'performedBy': value.performedBy,
      'createdAt': FirestoreFieldCodec.timestamp(value.createdAt),
      'note': value.note.trim(),
    });
  }
}
