enum CustomerType {
  retail('Khách lẻ'),
  agent('Đại lý'),
  business('Doanh nghiệp');

  const CustomerType(this.label);

  final String label;
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.customerType,
    required this.address,
    required this.isActive,
    this.email = '',
    this.note = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final CustomerType customerType;
  final String address;
  final bool isActive;
  final String email;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    CustomerType? customerType,
    String? address,
    bool? isActive,
    String? email,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      customerType: customerType ?? this.customerType,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'customerType': customerType.name,
        'address': address,
        'isActive': isActive,
        'email': email,
        'note': note,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        customerType:
            CustomerType.values.byName(json['customerType'] as String),
        address: json['address'] as String,
        isActive: json['isActive'] as bool? ?? true,
        email: json['email'] as String? ?? '',
        note: json['note'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}
