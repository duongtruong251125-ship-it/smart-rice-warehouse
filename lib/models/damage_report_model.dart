enum DamageReason {
  baoRach('Bao rách'),
  baoUot('Bao ướt'),
  moc('Mốc ẩm'),
  conTrung('Côn trùng / Mối mọt'),
  haoHut('Hao hụt vận chuyển'),
  khac('Lý do khác');

  const DamageReason(this.label);
  final String label;
}

enum DamageReportStatus {
  confirmed('Đã xử lý giảm tồn'),
  pending('Chờ duyệt'),
  rejected('Đã hủy');

  const DamageReportStatus(this.label);
  final String label;
}

class DamageReportModel {
  const DamageReportModel({
    required this.id,
    required this.code,
    required this.batchId,
    required this.batchCode,
    required this.riceId,
    required this.riceName,
    required this.quantity,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
    this.note,
    this.imagePath,
    this.status = DamageReportStatus.confirmed,
  });

  final String id;
  final String code; // e.g. 'BH-202610-001'
  final String batchId;
  final String batchCode;
  final String riceId;
  final String riceName;
  final double quantity; // Số lượng gạo bị hỏng (kg)
  final DamageReason reason;
  final String? note;
  final String? imagePath;
  final String createdBy;
  final DateTime createdAt;
  final DamageReportStatus status;

  DamageReportModel copyWith({
    String? id,
    String? code,
    String? batchId,
    String? batchCode,
    String? riceId,
    String? riceName,
    double? quantity,
    DamageReason? reason,
    String? note,
    String? imagePath,
    String? createdBy,
    DateTime? createdAt,
    DamageReportStatus? status,
  }) {
    return DamageReportModel(
      id: id ?? this.id,
      code: code ?? this.code,
      batchId: batchId ?? this.batchId,
      batchCode: batchCode ?? this.batchCode,
      riceId: riceId ?? this.riceId,
      riceName: riceName ?? this.riceName,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
