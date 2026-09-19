// FILE: lib/models/trip_model.dart
class TripModel {
  final String id;
  final String personId;
  final String personName;
  final String operation;
  final String date;
  final String vehicle;
  final String driver;
  final String item;
  final double weight;
  final double price;
  final double nolon; // الحقل الجديد للنولون
  final double total;
  final String notes;
  final String? sourceTripId;

  TripModel({
    required this.id,
    required this.personId,
    this.personName = '',
    required this.operation,
    required this.date,
    this.vehicle = '',
    this.driver = '',
    required this.item,
    required this.weight,
    required this.price,
    this.nolon = 0.0, // قيمة افتراضية
    required this.total,
    this.notes = '',
    this.sourceTripId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'person_id': personId,
    'operation': operation,
    'date': date,
    'vehicle': vehicle,
    'driver': driver,
    'item': item,
    'weight': weight,
    'price': price,
    'nolon': nolon, // إضافته لقاعدة البيانات
    'total': total,
    'notes': notes,
    'source_trip_id': sourceTripId,
  };

  factory TripModel.fromMap(Map<String, dynamic> map) => TripModel(
    id: map['id'],
    personId: map['person_id'],
    personName: map['person_name'] ?? '',
    operation: map['operation'],
    date: map['date'],
    vehicle: map['vehicle'] ?? '',
    driver: map['driver'] ?? '',
    item: map['item'],
    weight: (map['weight'] as num).toDouble(),
    price: (map['price'] as num).toDouble(),
    nolon: (map['nolon'] as num?)?.toDouble() ?? 0.0, // قراءته من قاعدة البيانات
    total: (map['total'] as num).toDouble(),
    notes: map['notes'] ?? '',
    sourceTripId: map['source_trip_id'],
  );
}
