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

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id, // Cho autoincrement
      'date': date.toIso8601String(),
      'totalQuantity': totalQuantity,
      'totalValue': totalValue,
      'note': note,
    };
  }

  factory InventorySnapshotModel.fromMap(Map<String, dynamic> map) {
    return InventorySnapshotModel(
      id: map['id'] as int,
      date: DateTime.parse(map['date'] as String),
      totalQuantity: (map['totalQuantity'] as num).toDouble(),
      totalValue: (map['totalValue'] as num).toDouble(),
      note: map['note'] as String? ?? '',
    );
  }
}
