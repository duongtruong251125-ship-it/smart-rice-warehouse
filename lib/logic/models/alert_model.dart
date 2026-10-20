enum AlertType {
  lowStock('Tồn thấp'),
  expiringSoon('Sắp hết hạn'),
  expired('Đã hết hạn');

  const AlertType(this.label);
  final String label;
}

enum AlertSeverity {
  info('Thông tin'),
  warning('Cảnh báo'),
  critical('Nghiêm trọng');

  const AlertSeverity(this.label);
  final String label;
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.type,
    required this.riceId,
    required this.riceName,
    this.batchId,
    this.batchCode,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final AlertType type;
  final String riceId;
  final String riceName;
  final String? batchId;
  final String? batchCode;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime createdAt;
  final bool isRead;

  AlertModel copyWith({
    String? id,
    AlertType? type,
    String? riceId,
    String? riceName,
    String? batchId,
    String? batchCode,
    String? title,
    String? message,
    AlertSeverity? severity,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AlertModel(
      id: id ?? this.id,
      type: type ?? this.type,
      riceId: riceId ?? this.riceId,
      riceName: riceName ?? this.riceName,
      batchId: batchId ?? this.batchId,
      batchCode: batchCode ?? this.batchCode,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
