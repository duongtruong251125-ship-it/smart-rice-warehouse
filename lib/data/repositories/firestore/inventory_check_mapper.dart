import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/inventory_check_model.dart';

class InventoryCheckMapper
    implements FirestoreModelMapper<InventoryCheckSession> {
  const InventoryCheckMapper();

  @override
  InventoryCheckSession fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  InventoryCheckSession fromMap(String id, Map<String, dynamic> data) {
    InventoryCheckStatus status = InventoryCheckStatus.inProgress;
    final statusStr = data['status'] as String?;
    if (statusStr != null) {
      try {
        status = InventoryCheckStatus.values.byName(statusStr);
      } catch (_) {
        status = InventoryCheckStatus.inProgress;
      }
    }

    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((map) => InventoryCheckItem.fromJson(map))
        .toList(growable: false);

    return InventoryCheckSession(
      id: id,
      code: data['code'] as String? ?? '',
      createdAt:
          FirestoreFieldCodec.dateTime(data['createdAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? 'system',
      status: status,
      items: items,
      totalItems: (data['totalItems'] as num?)?.toInt() ?? items.length,
      totalDifference: FirestoreFieldCodec.number(data['totalDifference']),
      completedAt: FirestoreFieldCodec.dateTime(data['completedAt']),
      note: data['note'] as String?,
    );
  }

  @override
  Map<String, Object?> toFirestore(
    InventoryCheckSession value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'createdAt': FirestoreFieldCodec.timestamp(value.createdAt),
      'createdBy': value.createdBy.trim(),
      'status': value.status.name,
      'items': value.items.map((i) => i.toJson()).toList(),
      'totalItems': value.totalItems,
      'totalDifference': value.totalDifference,
      'completedAt': value.completedAt == null
          ? null
          : FirestoreFieldCodec.timestamp(value.completedAt!),
      'note': value.note?.trim(),
    });
  }
}
