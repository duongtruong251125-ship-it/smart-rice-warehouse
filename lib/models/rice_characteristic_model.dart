class RiceCharacteristicModel {
  const RiceCharacteristicModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final bool isDefault;

  RiceCharacteristicModel copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    bool? isDefault,
  }) {
    return RiceCharacteristicModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'colorValue': colorValue,
        'isDefault': isDefault,
      };

  factory RiceCharacteristicModel.fromJson(Map<String, dynamic> json) =>
      RiceCharacteristicModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF0D9488,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
