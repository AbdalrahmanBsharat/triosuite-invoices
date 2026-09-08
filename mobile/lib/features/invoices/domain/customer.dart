/// A party an invoice is billed to.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.active = true,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final bool active;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}
