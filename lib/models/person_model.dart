class PersonModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final double openingReceivable;
  final double openingPayable;

  PersonModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.openingReceivable = 0.0,
    this.openingPayable = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'notes': notes,
    'opening_receivable': openingReceivable,
    'opening_payable': openingPayable,
  };

  factory PersonModel.fromMap(Map<String, dynamic> map) => PersonModel(
    id: map['id'],
    name: map['name'],
    phone: map['phone'] ?? '',
    address: map['address'] ?? '',
    notes: map['notes'] ?? '',
    openingReceivable: (map['opening_receivable'] as num?)?.toDouble() ?? 0.0,
    openingPayable: (map['opening_payable'] as num?)?.toDouble() ?? 0.0,
  );
}
