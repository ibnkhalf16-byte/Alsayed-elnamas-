import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../../core/accounting/accounting_engine.dart';
import '../settings/settings_screen.dart';
import '../statements/statement_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({Key? key}) : super(key: key);

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<PersonModel> _persons = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonsAndBalances();
  }

  Future<void> _loadPersonsAndBalances() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons', orderBy: 'name ASC');
    final tMaps = await db.query('trips');
    final payMaps = await db.query('payments');

    final persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
    final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final payments = payMaps.map((m) => PaymentModel.fromMap(m)).toList();

    Map<String, double> balancesMap = {};
    for (var p in persons) {
      final events = AccountingEngine.calculateStatement(p, trips, payments);
      final lastBalance = events.isNotEmpty ? (events.last['balance'] as double) : 0.0;
      balancesMap[p.id] = lastBalance;
    }

    if (mounted) {
      setState(() {
        _persons = persons;
        _balances = balancesMap;
        _isLoading = false;
      });
    }
  }

  void openPersonDialog({PersonModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final recCtrl = TextEditingController(text: existing != null ? existing.openingReceivable.toString() : '0');
    final payCtrl = TextEditingController(text: existing != null ? existing.openingPayable.toString() : '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'تعديل بيانات طرف' : 'إضافة طرف جديد (عميل / مورد)'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم بالكامل'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'العنوان أو المركز'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: recCtrl,
                          decoration: const InputDecoration(labelText: 'أول المدة (لك عنده)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: payCtrl,
                          decoration: const InputDecoration(labelText: 'أول المدة (له عندك)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final rec = double.tryParse(recCtrl.text.trim()) ?? 0.0;
                final pay = double.tryParse(payCtrl.text.trim()) ?? 0.0;
                final db = await DatabaseHelper.instance.database;

                if (isEdit) {
                  final isAuthorized = await SettingsScreen.verifyPassword(context);
                  if (!isAuthorized) return;

                  final updated = PersonModel(
                    id: existing.id,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    openingReceivable: rec,
                    openingPayable: pay,
                  );
                  await db.update('persons', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                } else {
                  final newP = PersonModel(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    openingReceivable: rec,
                    openingPayable: pay,
                  );
                  await db.insert('persons', newP.toMap());
                }

                Navigator.pop(ctx);
                _loadPersonsAndBalances();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دليل العملاء والموردين')),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => openPersonDialog(),
          child: const Icon(Icons.person_add),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _persons.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد عملاء أو موردون مسجلون',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _persons.length,
                    itemBuilder: (ctx, i) {
                      final p = _persons[i];
                      final balance = _balances[p.id] ?? 0.0;
                      final isReceivable = balance >= 0;

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StatementScreen(initialPerson: p),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isReceivable ? Icons.arrow_downward : Icons.arrow_upward,
                                      size: 22,
                                      color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.phone.isNotEmpty ? p.phone : (p.address.isNotEmpty ? p.address : 'بدون بيانات إضافية'),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      AppFormatters.formatCurrency(balance.abs()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                      ),
                                    ),
                                    Text(
                                      isReceivable ? 'مستحق (لك عنده)' : 'مطلوب (له عندك)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      openPersonDialog(existing: p);
                                    } else if (val == 'delete') {
                                      final isAuthorized = await SettingsScreen.verifyPassword(context);
                                      if (!isAuthorized) return;

                                      final db = await DatabaseHelper.instance.database;
                                      await db.delete('persons', where: 'id = ?', whereArgs: [p.id]);
                                      _loadPersonsAndBalances();
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف الطرف', style: TextStyle(color: AppColors.payableRed)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
