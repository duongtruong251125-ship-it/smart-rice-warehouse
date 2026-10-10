class RiceModel {
  const RiceModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.minimumStock,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double minimumStock;
  final String description;
  final bool isActive;

  RiceModel copyWith({
    String? id,
    String? code,
    String? name,
    String? category,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? minimumStock,
    String? description,
    bool? isActive,
  }) {
    return RiceModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'unit': unit,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'minimumStock': minimumStock,
        'description': description,
        'isActive': isActive,
      };

  factory RiceModel.fromJson(Map<String, dynamic> json) => RiceModel(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        unit: json['unit'] as String,
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num).toDouble(),
        minimumStock: (json['minimumStock'] as num).toDouble(),
        description: json['description'] as String,
        isActive: json['isActive'] as bool,
      );
}
