class BatchAllocation {
  const BatchAllocation({
    required this.batchId,
    required this.batchCode,
    required this.allocatedQuantity,
    required this.batchInitialQuantity,
    required this.batchRemainingQuantity,
    required this.expiryDate,
  });

  final String batchId;
  final String batchCode;
  final double allocatedQuantity;
  final double batchInitialQuantity;
  final double batchRemainingQuantity;
  final DateTime expiryDate;

  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'batchCode': batchCode,
      'allocatedQuantity': allocatedQuantity,
      'batchInitialQuantity': batchInitialQuantity,
      'batchRemainingQuantity': batchRemainingQuantity,
      'expiryDate': expiryDate.toIso8601String(),
    };
  }

  factory BatchAllocation.fromMap(Map<String, dynamic> map) {
    return BatchAllocation(
      batchId: map['batchId'] as String,
      batchCode: map['batchCode'] as String,
      allocatedQuantity: (map['allocatedQuantity'] as num).toDouble(),
      batchInitialQuantity: (map['batchInitialQuantity'] as num).toDouble(),
      batchRemainingQuantity: (map['batchRemainingQuantity'] as num).toDouble(),
      expiryDate: DateTime.parse(map['expiryDate'] as String),
    );
  }
}
