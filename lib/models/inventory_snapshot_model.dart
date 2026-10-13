class InventorySnapshotModel {
  final int id;
  final DateTime date;
  final double totalQuantity;
  final double totalValue;
  final String note;

  const InventorySnapshotModel({
    required this.id,
    required this.date,
    required this.totalQuantity,
    required this.totalValue,
    this.note = '',
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'totalQuantity': totalQuantity,
      'totalValue': totalValue,
      'note': note,
    };
  }

  Map<String, Object?> toMap() => toJson();

  factory InventorySnapshotModel.fromJson(Map<String, dynamic> map) {
    return InventorySnapshotModel(
      id: (map['id'] as num).toInt(),
      date: DateTime.parse(map['date'] as String),
      totalQuantity: (map['totalQuantity'] as num).toDouble(),
      totalValue: (map['totalValue'] as num).toDouble(),
      note: map['note'] as String? ?? '',
    );
  }

  factory InventorySnapshotModel.fromMap(Map<String, dynamic> map) =>
      InventorySnapshotModel.fromJson(map);
}
