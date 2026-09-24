
class FreightModel {
  final String id;
  final String date;
  final String clientId;
  final String clientName; // يُستخدم للعرض فقط
  final String supplierName;
  final String loadingPoint;
  final String unloadingPoint;
  final String itemType;
  final double weight;
  final double freightRate; // النولون
  final double additions; // إضافات
  final double shortage; // عجز
  final double total; // الإجمالي
  final double paid; // مسدد
  final double due; // المستحق
  final String notes;

  FreightModel({
    required this.id,
    required this.date,
    required this.clientId,
    this.clientName = '',
    this.supplierName = '',
    this.loadingPoint = '',
    this.unloadingPoint = '',
    this.itemType = '',
    required this.weight,
    required this.freightRate,
    this.additions = 0.0,
    this.shortage = 0.0,
    required this.total,
    this.paid = 0.0,
    required this.due,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'client_id': clientId,
    'supplier_name': supplierName,
    'loading_point': loadingPoint,
    'unloading_point': unloadingPoint,
    'item_type': itemType,
    'weight': weight,
    'freight_rate': freightRate,
    'additions': additions,
    'shortage': shortage,
    'total': total,
    'paid': paid,
    'due': due,
    'notes': notes,
  };

  factory FreightModel.fromMap(Map<String, dynamic> map) => FreightModel(
    id: map['id'],
    date: map['date'],
    clientId: map['client_id'],
    clientName: map['client_name'] ?? '',
    supplierName: map['supplier_name'] ?? '',
    loadingPoint: map['loading_point'] ?? '',
    unloadingPoint: map['unloading_point'] ?? '',
    itemType: map['item_type'] ?? '',
    weight: (map['weight'] as num).toDouble(),
    freightRate: (map['freight_rate'] as num).toDouble(),
    additions: (map['additions'] as num?)?.toDouble() ?? 0.0,
    shortage: (map['shortage'] as num?)?.toDouble() ?? 0.0,
    total: (map['total'] as num).toDouble(),
    paid: (map['paid'] as num?)?.toDouble() ?? 0.0,
    due: (map['due'] as num).toDouble(),
    notes: map['notes'] ?? '',
  );
}
