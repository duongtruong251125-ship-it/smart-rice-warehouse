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
}
