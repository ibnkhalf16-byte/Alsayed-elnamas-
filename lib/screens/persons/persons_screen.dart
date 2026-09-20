import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/accounting/accounting_engine.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../statements/statement_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({Key? key}) : super(key: key);

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<Map<String, dynamic>> _personsWithBalances = [];
  List<Map<String, dynamic>> _filteredPersons = [];

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPersonsAndCalculateBalances();
  }

  Future<void> _loadPersonsAndCalculateBalances() async {
    setState(() {
      _isLoading = true;
    });

    final supabase = Supabase.instance.client;

    final personsData = await supabase.from('persons').select();
    final tripsData = await supabase.from('trips').select();
    final paymentsData = await supabase.from('payments').select();

    final List<PersonModel> persons = personsData
        .map((e) => PersonModel.fromMap(e))
        .toList();

    final List<TripModel> allTrips = tripsData
        .map((e) => TripModel.fromMap(e))
        .toList();

    final List<PaymentModel> allPayments = paymentsData
        .map((e) => PaymentModel.fromMap(e))
        .toList();

    final List<Map<String, dynamic>> computedList = [];

    for (final person in persons) {
      final statement = AccountingEngine.calculateStatement(
        person,
        allTrips,
        allPayments,
      );

      double actualBalance = 0.0;

      if (statement.isNotEmpty) {
        actualBalance =
            (statement.last['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
        actualBalance = person.openingReceivable - person.openingPayable;
      }

      computedList.add({
        'person': person,
        'actual_balance': actualBalance,
      });
    }

    if (!mounted) return;

    setState(() {
      _personsWithBalances = computedList;
      if (_searchQuery.isNotEmpty) {
        _filterPersons(_searchQuery);
      } else {
        _filteredPersons = computedList;
      }
      _isLoading = false;
    });
  }

  void _filterPersons(String query) {
    setState(() {
      _searchQuery = query;
      _filteredPersons = _personsWithBalances.where((p) {
        final person = p['person'] as PersonModel;
        return person.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void openPersonDialog({PersonModel? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final recCtrl = TextEditingController(
        text: existing != null ? existing.openingReceivable.toString() : '0');
    final payCtrl = TextEditingController(
        text: existing != null ? existing.openingPayable.toString() : '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
              isEdit ? 'تعديل بيانات طرف' : 'إضافة طرف جديد (عميل / مورد)'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'الاسم بالكامل'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
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
                    decoration:
                        const InputDecoration(labelText: 'العنوان أو المركز'),
                  ),
                  const SizedBox(height: 16),
                  const Text('رصيد أول المدة',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: recCtrl,
                    decoration: const InputDecoration(
                      labelText: 'لك عنده (المبلغ الذي يدين لك به)',
                      labelStyle: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold),
                      prefixIcon:
                          Icon(Icons.arrow_downward, color: Color(0xFF10B981)),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '0');
                      if (val != null && val < 0) {
                        return 'لا يمكن إدخال قيمة سالبة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: payCtrl,
                    decoration: const InputDecoration(
                      labelText: 'له عندك (المبلغ الذي تدين له به)',
                      labelStyle: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold),
                      prefixIcon:
                          Icon(Icons.arrow_upward, color: Color(0xFFEF4444)),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '0');
                      if (val != null && val < 0) {
                        return 'لا يمكن إدخال قيمة سالبة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final rec = double.tryParse(recCtrl.text.trim()) ?? 0.0;
                final pay = double.tryParse(payCtrl.text.trim()) ?? 0.0;

                if (rec > 0 && pay > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'الرجاء إدخال رصيد في جهة واحدة فقط (إما لك عنده أو له عندك)')),
                  );
                  return;
                }

                final supabase = Supabase.instance.client;

                if (isEdit) {
                  final updated = PersonModel(
                    id: existing.id,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    openingReceivable: rec,
                    openingPayable: pay,
                  );
                  await supabase
                      .from('persons')
                      .update(updated.toMap())
                      .eq('id', existing.id);
                } else {
                  final newP = PersonModel(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    openingReceivable: rec,
                    openingPayable: pay,
                  );
                  await supabase.from('persons').insert(newP.toMap());
                }

                Navigator.pop(ctx);
                _loadPersonsAndCalculateBalances();
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('دليل العملاء والموردين'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                onChanged: _filterPersons,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الطرف...',
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredPersons.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد أطراف مسجلة أو مطابقة للبحث',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredPersons.length,
                        itemBuilder: (context, index) {
                          final data = _filteredPersons[index];
                          final PersonModel person =
                              data['person'] as PersonModel;
                          final double balance =
                              (data['actual_balance'] as num).toDouble();

                          final bool isOwedToYou = balance > 0;
                          final bool isOwedByYou = balance < 0;

                          Color statusColor = Colors.grey;
                          String statusText = 'رصيد مصفر';

                          if (isOwedToYou) {
                            statusColor = const Color(0xFF10B981);
                            statusText = 'مستحق لك عنده';
                          } else if (isOwedByYou) {
                            statusColor = const Color(0xFFEF4444);
                            statusText = 'مطلوب له عندك';
                          }

                          return Directionality(
                            textDirection: TextDirection.rtl,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: statusColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      statusColor.withOpacity(0.1),
                                  child: Text(
                                    person.name.isNotEmpty
                                        ? person.name.substring(0, 1)
                                        : '?',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${balance.abs().toStringAsFixed(2)} ج.م',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      openPersonDialog(existing: person);
                                    } else if (val == 'delete') {
                                      final supabase = Supabase.instance.client;
                                      await supabase
                                          .from('persons')
                                          .delete()
                                          .eq('id', person.id);
                                      _loadPersonsAndCalculateBalances();
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('تعديل البيانات')),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف الطرف',
                                          style: TextStyle(
                                              color: Color(0xFFEF4444))),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StatementScreen(
                                        initialPerson: person,
                                      ),
                                    ),
                                  ).then(
                                    (_) =>
                                        _loadPersonsAndCalculateBalances(),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Directionality(
        textDirection: TextDirection.rtl,
        child: FloatingActionButton.extended(
          onPressed: () => openPersonDialog(),
          backgroundColor: const Color(0xFF1E3A8A),
          icon: const Icon(
            Icons.person_add,
            color: Colors.white,
          ),
          label: const Text(
            'إضافة طرف',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
