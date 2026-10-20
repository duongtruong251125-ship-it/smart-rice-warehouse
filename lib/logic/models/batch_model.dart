enum BatchStatus {
  available('Còn hàng'),
  lowStock('Sắp hết'),
  expired('Hết hạn'),
  qualityHold('Tạm giữ');

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
    this.supplierId,
    this.supplierName,
    this.warehouseLocationId,
    this.locationName,
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
  final String? supplierId;
  final String? supplierName;
  final String? warehouseLocationId;
  final String? locationName;

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
    String? supplierId,
    String? supplierName,
    String? warehouseLocationId,
    String? locationName,
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
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      warehouseLocationId: warehouseLocationId ?? this.warehouseLocationId,
      locationName: locationName ?? this.locationName,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'riceId': riceId,
        'riceName': riceName,
        'quantity': quantity,
        'importDate': importDate.toIso8601String(),
        'manufactureDate': manufactureDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'status': status.name,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'warehouseLocationId': warehouseLocationId,
        'locationName': locationName,
      };

  factory BatchModel.fromJson(Map<String, dynamic> json) => BatchModel(
        id: json['id'] as String,
        code: json['code'] as String,
        riceId: json['riceId'] as String,
        riceName: json['riceName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        importDate: DateTime.parse(json['importDate'] as String),
        manufactureDate: DateTime.parse(json['manufactureDate'] as String),
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        status: BatchStatus.values.byName(json['status'] as String),
        supplierId: json['supplierId'] as String?,
        supplierName: json['supplierName'] as String?,
        warehouseLocationId: json['warehouseLocationId'] as String?,
        locationName: json['locationName'] as String?,
      );
}
