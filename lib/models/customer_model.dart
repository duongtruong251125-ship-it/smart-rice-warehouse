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
  });

  final String id;
  final String name;
  final String phone;
  final CustomerType customerType;
  final String address;
  final bool isActive;

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    CustomerType? customerType,
    String? address,
    bool? isActive,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      customerType: customerType ?? this.customerType,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
    );
  }
}
