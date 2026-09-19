import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/payment_model.dart';
import '../../models/person_model.dart';
import '../settings/settings_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final String? initialDirection; // 'from_customer' or 'to_supplier'

  const PaymentsScreen({Key? key, this.initialDirection}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentModel> _payments = [];
  List<PersonModel> _persons = [];
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
    final payMaps = await db.rawQuery('''
      SELECT py.*, p.name as person_name 
      FROM payments py 
      JOIN persons p ON py.person_id = p.id 
      ORDER BY py.date DESC, py.created_at DESC
    ''');

    if (mounted) {
      setState(() {
        _persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
        _payments = payMaps.map((m) => PaymentModel.fromMap(m)).toList();
        _isLoading = false;
      });
    }
  }

  void openPaymentDialog({PaymentModel? existing, String? initialPersonId, String? preselectedDirection}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    String? selectedPerson = existing?.personId ?? initialPersonId;
    
    String direction = existing?.direction ?? (preselectedDirection ?? widget.initialDirection ?? 'to_supplier');
    
    // قفل نوع العملية إذا تم الدخول للشاشة بنوع محدد
    bool isDirectionLocked = (preselectedDirection != null) || (widget.initialDirection != null) || existing != null;

    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ?? DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate));
    final amtCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'تعديل سند سداد' : 'تسجيل سند سداد'),
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
                      validator: (v) => v == null ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'to_supplier', label: Text('سداد لمورد (صادر)')),
                        ButtonSegment(value: 'from_customer', label: Text('تحصيل من عميل (وارد)')),
                      ],
                      selected: {direction},
                      onSelectionChanged: isDirectionLocked 
                        ? (s) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('نوع السند ثابت من هذه الشاشة ولا يمكن تغييره'))
                             );
                          }
                        : (s) => setModalState(() => direction = s.first),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amtCtrl,
                      decoration: const InputDecoration(labelText: 'المبلغ (جنيه مصري)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'مبلغ غير صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'البيان / الوصف (اختياري)'),
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
                  final amt = double.parse(amtCtrl.text.trim());
                  final db = await DatabaseHelper.instance.database;

                  if (isEdit) {
                    final isAuthorized = await SettingsScreen.verifyPassword(context);
                    if (!isAuthorized) return;

                    final updated = PaymentModel(
                      id: existing.id,
                      personId: selectedPerson!,
                      paymentType: 'cash',
                      direction: direction,
                      date: dateCtrl.text,
                      amount: amt,
                      description: descCtrl.text.trim(),
                    );
                    await db.update('payments', updated.toMap(), where: 'id = ?', whereArgs: [existing.id]);
                  } else {
                    final newPay = PaymentModel(
                      id: const Uuid().v4(),
                      personId: selectedPerson!,
                      paymentType: 'cash',
                      direction: direction,
                      date: dateCtrl.text,
                      amount: amt,
                      description: descCtrl.text.trim(),
                    );
                    await db.insert('payments', newPay.toMap());
                  }

                  Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text('حفظ السند'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تصفية القائمة بناءً على المعامل المرر إذا كان موجوداً
    final filteredPayments = _payments.where((p) {
      if (widget.initialDirection != null && p.direction != widget.initialDirection) return false;
      return true;
    }).toList();

    // تخصيص عنوان الشاشة
    String appBarTitle = 'سندات السداد والتحصيل';
    if (widget.initialDirection == 'from_customer') appBarTitle = 'سندات التحصيل النقدية';
    if (widget.initialDirection == 'to_supplier') appBarTitle = 'سندات سداد الدفعات';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => openPaymentDialog(preselectedDirection: widget.initialDirection),
          child: const Icon(Icons.add),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredPayments.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد سندات مسجلة حالياً',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredPayments.length,
                    itemBuilder: (ctx, i) {
                      final p = filteredPayments[i];
                      final isFromCustomer = p.direction == 'from_customer';

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isFromCustomer ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            child: Icon(
                              isFromCustomer ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isFromCustomer ? AppColors.receivableGreen : AppColors.payableRed,
                            ),
                          ),
                          title: Text(
                            '${p.personName} - ${AppFormatters.formatCurrency(p.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${isFromCustomer ? "تحصيل وارد من عميل" : "سداد صادر لمورد"} | ${p.date}\n${p.description.isNotEmpty ? p.description : "بدون بيان إضافي"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => openPaymentDialog(existing: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.payableRed),
                                onPressed: () async {
                                  final isAuthorized = await SettingsScreen.verifyPassword(context);
                                  if (!isAuthorized) return;

                                  final db = await DatabaseHelper.instance.database;
                                  await db.delete('payments', where: 'id = ?', whereArgs: [p.id]);
                                  _loadData();
                                },
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
