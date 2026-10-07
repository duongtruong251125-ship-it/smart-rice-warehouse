class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.taxCode,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String taxCode;
  final bool isActive;

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    bool? isActive,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxCode: taxCode ?? this.taxCode,
      isActive: isActive ?? this.isActive,
    );
  }
}
