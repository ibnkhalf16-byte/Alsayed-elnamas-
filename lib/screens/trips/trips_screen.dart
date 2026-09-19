// FILE: lib/screens/trips/trips_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/database/database_helper.dart';
import '../../core/accounting/accounting_engine.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/trip_model.dart';
import '../../models/person_model.dart';
import '../settings/settings_screen.dart';

class TripsScreen extends StatefulWidget {
  final String? initialOperation;

  const TripsScreen({Key? key, this.initialOperation}) : super(key: key);

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<TripModel> _trips = [];
  List<PersonModel> _persons = [];
  Map<String, String> _statuses = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons', orderBy: 'name ASC');
    final tMaps = await db.rawQuery('''
      SELECT t.*, p.name as person_name 
      FROM trips t 
      JOIN persons p ON t.person_id = p.id 
      ORDER BY t.date DESC, t.created_at DESC
    ''');

    final personsList = pMaps.map((m) => PersonModel.fromMap(m)).toList();
    final tripsList = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final statusesMap = AccountingEngine.calculateTripStatuses(tripsList);

    if (mounted) {
      setState(() {
        _persons = personsList;
        _trips = tripsList;
        _statuses = statusesMap;
        _isLoading = false;
      });
    }
  }

  void openTripDialog({TripModel? existing, String? preselectedOperation}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    String? selectedPerson = existing?.personId;
    
    String operation = existing?.operation ?? (preselectedOperation ?? widget.initialOperation ?? 'purchase');
    bool isOperationLocked = (preselectedOperation != null) || (widget.initialOperation != null) || existing != null;

    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ?? DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate));
    final carCtrl = TextEditingController(text: existing?.vehicle ?? '');
    final driverCtrl = TextEditingController(text: existing?.driver ?? '');
    final itemCtrl = TextEditingController(text: existing?.item ?? '');
    final weightCtrl = TextEditingController(text: existing != null ? existing.weight.toString() : '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    // حقل الإدخال الجديد للنولون
    final nolonCtrl = TextEditingController(text: existing != null && existing.nolon > 0 ? existing.nolon.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEdit ? 'تعديل نقلة' : (operation == 'purchase' ? 'تسجيل نقلة شراء' : 'تسجيل نقلة بيع'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      title: Text(
                        'التاريخ: ${dateCtrl.text}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: AppColors.primary),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                            dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedPerson,
                      decoration: const InputDecoration(labelText: 'اختر الطرف (العميل / المورد)'),
                      items: _persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) => setModalState(() => selectedPerson = v),
                      validator: (v) => v == null ? 'يرجى اختيار الطرف' : null,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'purchase', label: Text('شراء من مورد')),
                        ButtonSegment(value: 'sale', label: Text('بيع لعميل')),
                      ],
                      selected: {operation},
                      onSelectionChanged: isOperationLocked 
                        ? (s) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('نوع العملية ثابت من هذه الشاشة ولا يمكن تغييره'))
                            );
                          }
                        : (s) => setModalState(() => operation = s.first),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: itemCtrl,
                      decoration: const InputDecoration(labelText: 'نوع البضاعة (قمح، ذرة، فول...)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: weightCtrl,
                            decoration: const InputDecoration(labelText: 'الوزن (طن)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              final val = double.tryParse(v);
                              if (val == null || val <= 0) return 'قيمة غير صحيحة';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(labelText: 'سعر الطن (ج.م)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              final val = double.tryParse(v);
                              if (val == null || val <= 0) return 'قيمة غير صحيحة';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // إضافة حقل النولون هنا
                    TextFormField(
                      controller: nolonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'النولون للطن (اختياري)',
                        hintText: 'قيمة النولون لكل طن',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                           if (double.tryParse(v) == null || double.parse(v) < 0) {
                             return 'قيمة غير صحيحة';
                           }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: carCtrl,
                            decoration: const InputDecoration(labelText: 'التحميل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: driverCtrl,
                            decoration: const InputDecoration(labelText: 'اسم السائق'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'ملاحظات إضافية'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || selectedPerson == null) return;
                  
                  final weight = double.parse(weightCtrl.text.trim());
                  final price = double.parse(priceCtrl.text.trim());
                  final nolon = nolonCtrl.text.trim().isNotEmpty ? double.parse(nolonCtrl.text.trim()) : 0.0;
                  
                  // المعادلة الجديدة: (السعر * الوزن) + (النولون * الوزن)
                  final total = (weight * price) + (weight * nolon);
                  
                  final db = await DatabaseHelper.instance.database;

                  if (isEdit) {
                    final isAuthorized = await SettingsScreen.verifyPassword(context);
                    if (!isAuthorized) return;

                    final updated = TripModel(
                      id: existing.id,
                      personId: selectedPerson!,
                      operation: operation,
                      date: dateCtrl.text,
                      vehicle: carCtrl.text.trim(),
                      driver: driverCtrl.text.trim(),
                      item: itemCtrl.text.trim(),
                      weight: weight,
                      price: price,
                      nolon: nolon, // حفظ النولون
                      total: total,
                      notes: notesCtrl.text.trim(),
                      sourceTripId: existing.sourceTripId,
                    );
                    await db.update('trips', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                  } else {
                    final newTrip = TripModel(
                      id: const Uuid().v4(),
                      personId: selectedPerson!,
                      operation: operation,
                      date: dateCtrl.text,
                      vehicle: carCtrl.text.trim(),
                      driver: driverCtrl.text.trim(),
                      item: itemCtrl.text.trim(),
                      weight: weight,
                      price: price,
                      nolon: nolon, // حفظ النولون
                      total: total,
                      notes: notesCtrl.text.trim(),
                    );
                    await db.insert('trips', newTrip.toMap());
                  }

                  Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text('حفظ النقلة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSellPurchaseModal(TripModel purchase) {
    final status = _statuses[purchase.id] ?? '';
    double remaining = purchase.weight;
    if (status.startsWith("متبقي للبيع:")) {
      remaining = double.tryParse(status.replaceAll("متبقي للبيع:", "").replaceAll("طن", "").trim()) ?? 0.0;
    } else if (status == "تم بيع الوزنة") {
      remaining = 0.0;
    }

    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('النقلة مباعة بالكامل بالفعل!'), backgroundColor: AppColors.warningOrange),
      );
      return;
    }

    String? selectedCustomer;
    DateTime saleDate = DateTime.now();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(saleDate));
    final weightCtrl = TextEditingController(text: remaining.toString());
    final priceCtrl = TextEditingController();
    final nolonCtrl = TextEditingController(); // نولون عند البيع

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('بيع ونقل من النقلة المشتراة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'الصنف: ${purchase.item} | سيارة: ${purchase.vehicle}\nالمتاح للبيع: ${remaining.toStringAsFixed(2)} طن',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    title: Text(
                      'تاريخ البيع: ${dateCtrl.text}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month, color: AppColors.receivableGreen),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: saleDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() {
                          saleDate = picked;
                          dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'العميل المشتري'),
                    items: _persons.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => selectedCustomer = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: weightCtrl,
                    decoration: const InputDecoration(labelText: 'الوزن المباع (طن)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'سعر بيع الطن (ج.م)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nolonCtrl,
                    decoration: const InputDecoration(labelText: 'نولون البيع للطن (اختياري)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final w = double.tryParse(weightCtrl.text.trim()) ?? 0;
                  final p = double.tryParse(priceCtrl.text.trim()) ?? 0;
                  final n = nolonCtrl.text.trim().isNotEmpty ? double.parse(nolonCtrl.text.trim()) : 0.0;
                  
                  if (selectedCustomer == null || w <= 0 || p <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى ملء جميع الحقول بصورة صحيحة')),
                    );
                    return;
                  }
                  if (w > remaining + 0.0001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الوزن المطلوب بيعه أكبر من الكمية المتاحة!')),
                    );
                    return;
                  }

                  final isAuthorized = await SettingsScreen.verifyPassword(context);
                  if (!isAuthorized) return;

                  // حساب الإجمالي مع النولون للبيع
                  final totalSale = (w * p) + (w * n);

                  final db = await DatabaseHelper.instance.database;
                  final saleTrip = TripModel(
                    id: const Uuid().v4(),
                    personId: selectedCustomer!,
                    operation: 'sale',
                    date: dateCtrl.text,
                    vehicle: purchase.vehicle,
                    driver: purchase.driver,
                    item: purchase.item,
                    weight: w,
                    price: p,
                    nolon: n,
                    total: totalSale,
                    sourceTripId: purchase.id,
                  );
                  await db.insert('trips', saleTrip.toMap());

                  Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text('تأكيد عملية البيع'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('تم بيع') || status.contains('تم شراء')) {
      return AppColors.receivableGreen;
    }
    if (status.contains('متبقي')) {
      return AppColors.warningOrange;
    }
    return AppColors.payableRed;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _trips.where((t) {
      if (widget.initialOperation != null && t.operation != widget.initialOperation) return false;
      
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return t.personName.toLowerCase().contains(q) ||
          t.item.toLowerCase().contains(q) ||
          t.vehicle.toLowerCase().contains(q) ||
          t.driver.toLowerCase().contains(q);
    }).toList();

    String appBarTitle = 'سجل النقلات والوزنات';
    if (widget.initialOperation == 'purchase') appBarTitle = 'سجل نقلات الشراء';
    if (widget.initialOperation == 'sale') appBarTitle = 'سجل نقلات البيع';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم الطرف، الصنف، السيارة، السائق...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => openTripDialog(preselectedOperation: widget.initialOperation),
          child: const Icon(Icons.add),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredTrips.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد نقلات مسجلة حالياً',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredTrips.length,
                    itemBuilder: (ctx, i) {
                      final t = filteredTrips[i];
                      final isSale = t.operation == 'sale';
                      final status = _statuses[t.id] ?? '';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSale ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isSale ? 'بيع لعميل' : 'شراء من مورد',
                                      style: TextStyle(
                                        color: isSale ? const Color(0xFF166534) : const Color(0xFF92400E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.personName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    t.date,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'الصنف: ${t.item}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    '${t.weight.toStringAsFixed(2)} طن × ${t.price.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'الإجمالي: ${AppFormatters.formatCurrency(t.total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  if (t.nolon > 0)
                                    Text(
                                      'نولون: ${t.nolon.toStringAsFixed(2)} للطن',
                                      style: const TextStyle(fontSize: 12, color: AppColors.warningOrange, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (t.vehicle.isNotEmpty || t.driver.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'سيارة: ${t.vehicle} | ${t.driver}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (!isSale)
                                        IconButton(
                                          icon: const Icon(Icons.sell_outlined, color: AppColors.primary, size: 20),
                                          tooltip: 'بيع ونقل مباشر لعميل',
                                          onPressed: () => _openSellPurchaseModal(t),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                                        tooltip: 'تعديل',
                                        onPressed: () => openTripDialog(existing: t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.payableRed, size: 20),
                                        tooltip: 'حذف',
                                        onPressed: () async {
                                          final isAuthorized = await SettingsScreen.verifyPassword(context);
                                          if (!isAuthorized) return;

                                          final db = await DatabaseHelper.instance.database;
                                          await db.delete('trips', where: 'id = ?', whereArgs: [t.id]);
                                          _loadData();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
