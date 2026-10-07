enum BatchStatus {
  available('Còn hàng'),
  lowStock('Sắp hết'),
  expired('Hết hạn');

  const BatchStatus(this.label);

  final String label;
}

class BatchModel {
  const BatchModel({
    required this.id,
    required this.code,
    required this.riceId,
    required this.riceName,
    required this.quantity,
    required this.importDate,
    required this.manufactureDate,
    required this.expiryDate,
    required this.status,
  });

  final String id;
  final String code;
  final String riceId;
  final String riceName;
  final double quantity;
  final DateTime importDate;
  final DateTime manufactureDate;
  final DateTime expiryDate;
  final BatchStatus status;

  BatchModel copyWith({
    String? id,
    String? code,
    String? riceId,
    String? riceName,
    double? quantity,
    DateTime? importDate,
    DateTime? manufactureDate,
    DateTime? expiryDate,
    BatchStatus? status,
  }) {
    return BatchModel(
      id: id ?? this.id,
      code: code ?? this.code,
      riceId: riceId ?? this.riceId,
      riceName: riceName ?? this.riceName,
      quantity: quantity ?? this.quantity,
      importDate: importDate ?? this.importDate,
      manufactureDate: manufactureDate ?? this.manufactureDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
    );
  }
}
