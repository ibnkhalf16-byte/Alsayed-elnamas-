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
  String _searchQuery = '';
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 16),
                  const Text('رصيد أول المدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: recCtrl,
                    decoration: const InputDecoration(
                      labelText: 'لك عنده (المبلغ الذي يدين لك به)',
                      labelStyle: TextStyle(color: AppColors.receivableGreen, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.arrow_downward, color: AppColors.receivableGreen),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                       final val = double.tryParse(v ?? '0');
                       if (val != null && val < 0) return 'لا يمكن إدخال قيمة سالبة';
                       return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: payCtrl,
                    decoration: const InputDecoration(
                      labelText: 'له عندك (المبلغ الذي تدين له به)',
                      labelStyle: TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.arrow_upward, color: AppColors.payableRed),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                       final val = double.tryParse(v ?? '0');
                       if (val != null && val < 0) return 'لا يمكن إدخال قيمة سالبة';
                       return null;
                    },
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
                
                if (rec > 0 && pay > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال رصيد في جهة واحدة فقط (إما لك عنده أو له عندك)')),
                  );
                  return;
                }
                
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
    final filteredPersons = _persons.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دليل العملاء والموردين'),
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
                    hintText: 'ابحث باسم الطرف...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => openPersonDialog(),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة طرف'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredPersons.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد أطراف مطابقة للبحث',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredPersons.length,
                    itemBuilder: (ctx, i) {
                      final p = filteredPersons[i];
                      final balance = _balances[p.id] ?? 0.0;
                      final isReceivable = balance >= 0;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isReceivable ? AppColors.receivableGreen.withOpacity(0.5) : AppColors.payableRed.withOpacity(0.5)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StatementScreen(initialPerson: p),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: isReceivable ? AppColors.receivableGreen.withOpacity(0.1) : AppColors.payableRed.withOpacity(0.1),
                                  child: Text(
                                    p.name.substring(0, 1),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      if (p.phone.isNotEmpty)
                                        Text(p.phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      isReceivable ? 'مستحق لك عنده' : 'مطلوب له عندك',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatCurrency(balance.abs()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                      ),
                                    ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
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
