class PaymentModel {
  final String id;
  final String personId;
  final String personName;
  final String paymentType; // 'cash'
  final String direction;   // 'to_supplier' or 'from_customer'
  final String date;
  final double amount;
  final String vehicle;
  final String driver;
  final String item;
  final double weight;
  final double price;
  final String description;

  PaymentModel({
    required this.id,
    required this.personId,
    this.personName = '',
    required this.paymentType,
    required this.direction,
    required this.date,
    required this.amount,
    this.vehicle = '',
    this.driver = '',
    this.item = '',
    this.weight = 0.0,
    this.price = 0.0,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'payment_type': paymentType,
    'direction': direction,
    'date': date,
    'amount': amount,
    'vehicle': vehicle,
    'driver': driver,
    'item': item,
    'weight': weight,
    'price': price,
    'description': description,
  };

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
    id: map['id'],
    personId: map['person_id'],
    personName: map['person_name'] ?? '',
    paymentType: map['payment_type'],
    direction: map['direction'],
    date: map['date'],
    amount: (map['amount'] as num).toDouble(),
    vehicle: map['vehicle'] ?? '',
    driver: map['driver'] ?? '',
    item: map['item'] ?? '',
    weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    description: map['description'] ?? '',
  );
}
