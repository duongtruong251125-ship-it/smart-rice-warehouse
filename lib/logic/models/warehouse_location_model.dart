class WarehouseLocationModel {
  const WarehouseLocationModel({
    required this.id,
    required this.zone,
    required this.rack,
    required this.shelf,
    required this.code,
    required this.capacity,
    this.currentBatchCount = 0,
    this.isActive = true,
    this.description,
  });

  final String id;
  final String zone; // e.g. 'Khu A', 'Khu B'
  final String rack; // e.g. 'Kệ 1', 'Kệ 2'
  final String shelf; // e.g. 'Tầng 1', 'Tầng 2'
  final String code; // e.g. 'A-K1-T1'
  final double capacity; // Sức chứa (kg)
  final int currentBatchCount; // Số lô đang lưu trữ
  final bool isActive;
  final String? description;

  String get fullDisplayName => '$zone → $rack → $shelf ($code)';

  WarehouseLocationModel copyWith({
    String? id,
    String? zone,
    String? rack,
    String? shelf,
    String? code,
    double? capacity,
    int? currentBatchCount,
    bool? isActive,
    String? description,
  }) {
    return WarehouseLocationModel(
      id: id ?? this.id,
      zone: zone ?? this.zone,
      rack: rack ?? this.rack,
      shelf: shelf ?? this.shelf,
      code: code ?? this.code,
      capacity: capacity ?? this.capacity,
      currentBatchCount: currentBatchCount ?? this.currentBatchCount,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'zone': zone,
      'rack': rack,
      'shelf': shelf,
      'code': code,
      'capacity': capacity,
      'currentBatchCount': currentBatchCount,
      'isActive': isActive,
      'description': description,
    };
  }

  factory WarehouseLocationModel.fromJson(Map<String, dynamic> json) {
    return WarehouseLocationModel(
      id: json['id'] as String,
      zone: json['zone'] as String,
      rack: json['rack'] as String,
      shelf: json['shelf'] as String,
      code: json['code'] as String,
      capacity: (json['capacity'] as num).toDouble(),
      currentBatchCount: (json['currentBatchCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }
}
