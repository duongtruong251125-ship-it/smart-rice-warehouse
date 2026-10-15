class StockMovementModel {
  const StockMovementModel({
    required this.id,
    required this.type,
    required this.batchId,
    required this.riceId,
    required this.quantityDelta,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.referenceType,
    required this.referenceId,
    required this.performedBy,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String type; // 'import', 'export', 'damage', 'inventoryCheck', 'adjustment'
  final String batchId;
  final String riceId;
  final double quantityDelta;
  final double quantityBefore;
  final double quantityAfter;
  final String referenceType;
  final String referenceId;
  final String performedBy;
  final DateTime createdAt;
  final String note;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'batchId': batchId,
        'riceId': riceId,
        'quantityDelta': quantityDelta,
        'quantityBefore': quantityBefore,
        'quantityAfter': quantityAfter,
        'referenceType': referenceType,
        'referenceId': referenceId,
        'performedBy': performedBy,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory StockMovementModel.fromJson(Map<String, dynamic> json) =>
      StockMovementModel(
        id: json['id'] as String,
        type: json['type'] as String,
        batchId: json['batchId'] as String,
        riceId: json['riceId'] as String,
        quantityDelta: (json['quantityDelta'] as num).toDouble(),
        quantityBefore: (json['quantityBefore'] as num).toDouble(),
        quantityAfter: (json['quantityAfter'] as num).toDouble(),
        referenceType: json['referenceType'] as String,
        referenceId: json['referenceId'] as String,
        performedBy: json['performedBy'] as String? ?? 'system',
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String? ?? '',
      );
}
