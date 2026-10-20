import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rice_warehouse/data/firebase/config/firestore_converters.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';

class DamageReportMapper implements FirestoreModelMapper<DamageReportModel> {
  const DamageReportMapper();

  @override
  DamageReportModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  DamageReportModel fromMap(String id, Map<String, dynamic> data) {
    DamageReason reason = DamageReason.khac;
    final reasonStr = data['reason'] as String?;
    if (reasonStr != null) {
      try {
        reason = DamageReason.values.byName(reasonStr);
      } catch (_) {
        reason = DamageReason.khac;
      }
    }

    DamageReportStatus status = DamageReportStatus.confirmed;
    final statusStr = data['status'] as String?;
    if (statusStr != null) {
      try {
        status = DamageReportStatus.values.byName(statusStr);
      } catch (_) {
        status = DamageReportStatus.confirmed;
      }
    }

    return DamageReportModel(
      id: id,
      code: data['code'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      batchCode: data['batchCode'] as String? ??
          data['batchCodeSnapshot'] as String? ??
          '',
      riceId: data['riceId'] as String? ?? '',
      riceName: data['riceName'] as String? ??
          data['riceNameSnapshot'] as String? ??
          '',
      quantity: FirestoreFieldCodec.number(data['quantity']),
      reason: reason,
      note: data['note'] as String?,
      imagePath: null, // Local persistent storage only
      createdBy: data['reportedBy'] as String? ??
          data['createdBy'] as String? ??
          'system',
      createdAt: FirestoreFieldCodec.dateTime(
              data['reportedAt'] ?? data['createdAt']) ??
          DateTime.now(),
      status: status,
    );
  }

  @override
  Map<String, Object?> toFirestore(
    DamageReportModel value,
    SetOptions? options,
  ) {
    return FirestoreFieldCodec.withoutNullValues({
      'code': value.code.trim(),
      'batchId': value.batchId.trim(),
      'batchCode': value.batchCode.trim(),
      'batchCodeSnapshot': value.batchCode.trim(),
      'riceId': value.riceId.trim(),
      'riceName': value.riceName.trim(),
      'riceNameSnapshot': value.riceName.trim(),
      'quantity': value.quantity,
      'reason': value.reason.name,
      'note': value.note?.trim(),
      'reportedBy': value.createdBy.trim(),
      'reportedAt': FirestoreFieldCodec.timestamp(value.createdAt),
      'createdAt': FirestoreFieldCodec.timestamp(value.createdAt),
      'status': value.status.name,
    });
  }
}
