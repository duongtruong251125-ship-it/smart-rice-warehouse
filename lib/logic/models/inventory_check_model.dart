enum InventoryCheckStatus {
  inProgress('Đang kiểm kê'),
  completed('Đã hoàn thành'),
  cancelled('Đã hủy');

  const InventoryCheckStatus(this.label);
  final String label;
}

enum InventoryCheckReason {
  none('Khớp số lượng'),
  haoHut('Hao hụt tự nhiên'),
  baoRach('Bao rách rơi vãi'),
  saiDuLieu('Sai lệch số liệu nhập'),
  matHang('Mất hàng / Thất thoát'),
  khac('Lý do khác');

  const InventoryCheckReason(this.label);
  final String label;
}

class InventoryCheckItem {
  const InventoryCheckItem({
    required this.batchId,
    required this.batchCode,
    required this.riceName,
    required this.expectedQuantity,
    required this.actualQuantity,
    required this.difference,
    this.reason = InventoryCheckReason.none,
    this.note,
  });

  final String batchId;
  final String batchCode;
  final String riceName;
  final double expectedQuantity;
  final double actualQuantity;
  final double difference; // actual - expected
  final InventoryCheckReason reason;
  final String? note;

  bool get hasDifference => difference.abs() > 0.001;

  InventoryCheckItem copyWith({
    String? batchId,
    String? batchCode,
    String? riceName,
    double? expectedQuantity,
    double? actualQuantity,
    double? difference,
    InventoryCheckReason? reason,
    String? note,
  }) {
    return InventoryCheckItem(
      batchId: batchId ?? this.batchId,
      batchCode: batchCode ?? this.batchCode,
      riceName: riceName ?? this.riceName,
      expectedQuantity: expectedQuantity ?? this.expectedQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      difference: difference ?? this.difference,
      reason: reason ?? this.reason,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => {
        'batchId': batchId,
        'batchCode': batchCode,
        'riceName': riceName,
        'expectedQuantity': expectedQuantity,
        'actualQuantity': actualQuantity,
        'difference': difference,
        'reason': reason.name,
        'note': note,
      };

  factory InventoryCheckItem.fromJson(Map<String, dynamic> json) =>
      InventoryCheckItem(
        batchId: json['batchId'] as String,
        batchCode: json['batchCode'] as String,
        riceName: json['riceName'] as String,
        expectedQuantity: (json['expectedQuantity'] as num).toDouble(),
        actualQuantity: (json['actualQuantity'] as num).toDouble(),
        difference: (json['difference'] as num).toDouble(),
        reason: InventoryCheckReason.values.byName(json['reason'] as String),
        note: json['note'] as String?,
      );
}

class InventoryCheckSession {
  const InventoryCheckSession({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.createdBy,
    required this.status,
    this.items = const <InventoryCheckItem>[],
    this.totalItems = 0,
    this.totalDifference = 0,
    this.completedAt,
    this.note,
  });

  final String id;
  final String code; // e.g. 'KK-202610-001'
  final DateTime createdAt;
  final String createdBy;
  final InventoryCheckStatus status;
  final List<InventoryCheckItem> items;
  final int totalItems;
  final double totalDifference;
  final DateTime? completedAt;
  final String? note;

  InventoryCheckSession copyWith({
    String? id,
    String? code,
    DateTime? createdAt,
    String? createdBy,
    InventoryCheckStatus? status,
    List<InventoryCheckItem>? items,
    int? totalItems,
    double? totalDifference,
    DateTime? completedAt,
    String? note,
  }) {
    return InventoryCheckSession(
      id: id ?? this.id,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      totalDifference: totalDifference ?? this.totalDifference,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'status': status.name,
        'items': items.map((item) => item.toJson()).toList(),
        'totalItems': totalItems,
        'totalDifference': totalDifference,
        'completedAt': completedAt?.toIso8601String(),
        'note': note,
      };

  factory InventoryCheckSession.fromJson(Map<String, dynamic> json) =>
      InventoryCheckSession(
        id: json['id'] as String,
        code: json['code'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        status: InventoryCheckStatus.values.byName(json['status'] as String),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => InventoryCheckItem.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        totalItems: (json['totalItems'] as num).toInt(),
        totalDifference: (json['totalDifference'] as num).toDouble(),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        note: json['note'] as String?,
      );
}
