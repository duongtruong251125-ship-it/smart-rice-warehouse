class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.taxCode,
    required this.isActive,
    this.note = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String taxCode;
  final bool isActive;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    bool? isActive,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxCode: taxCode ?? this.taxCode,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'taxCode': taxCode,
        'isActive': isActive,
        'note': note,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String? ?? '',
        address: json['address'] as String,
        taxCode: json['taxCode'] as String,
        isActive: json['isActive'] as bool? ?? true,
        note: json['note'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}
