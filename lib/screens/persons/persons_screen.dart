import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/accounting/accounting_engine.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../statements/statement_screen.dart';
import '../settings/settings_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final Uuid uuid = const Uuid();

  bool _loading = true;
  String _search = '';

  List<PersonModel> _persons = [];
  List<TripModel> _trips = [];
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final results = await Future.wait([
        supabase.from('persons').select().order('name', ascending: true),
        supabase.from('trips').select(),
        supabase.from('payments').select(),
      ]);

      final personsData = results[0] as List;
      final tripsData = results[1] as List;
      final paymentsData = results[2] as List;

      final persons = personsData
          .map(
            (item) => PersonModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final trips = tripsData
          .map(
            (item) => TripModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final payments = paymentsData
          .map(
            (item) => PaymentModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _persons = persons;
        _trips = trips;
        _payments = payments;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('PersonsScreen _loadData error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError('تعذر تحميل البيانات: ${_friendlySupabaseError(e)}');
    }
  }

  String _friendlySupabaseError(Object error) {
    final text = error.toString();

    if (text.contains('42501') ||
        text.toLowerCase().contains('row-level security')) {
      return 'ليس لديك صلاحية للوصول إلى البيانات. راجع سياسات RLS في Supabase.';
    }

    if (text.toLowerCase().contains('network')) {
      return 'تعذر الاتصال بالإنترنت أو بخادم Supabase.';
    }

    if (text.toLowerCase().contains('socket')) {
      return 'تعذر الاتصال بخادم Supabase.';
    }

    return text;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  List<PersonModel> get _filteredPersons {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _persons;
    }

    return _persons.where((person) {
      return person.name.toLowerCase().contains(query) ||
          person.phone.toLowerCase().contains(query) ||
          person.address.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _handleAddPerson() async {
    final authorized = await SettingsScreen.verifyPassword(context);

    if (!authorized || !mounted) return;

    await _openPersonDialog();
  }

  Future<void> _handleEditPerson(PersonModel person) async {
    final authorized = await SettingsScreen.verifyPassword(context);

    if (!authorized || !mounted) return;

    await _openPersonDialog(existing: person);
  }

  Future<void> _openPersonDialog({
    PersonModel? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    final phoneController = TextEditingController(
      text: existing?.phone ?? '',
    );

    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );

    final notesController = TextEditingController(
      text: existing?.notes ?? '',
    );

    final openingReceivableController = TextEditingController(
      text: existing == null || existing.openingReceivable == 0
          ? ''
          : existing.openingReceivable.toString(),
    );

    final openingPayableController = TextEditingController(
      text: existing == null || existing.openingPayable == 0
          ? ''
          : existing.openingPayable.toString(),
    );

    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(
                  existing == null
                      ? 'إضافة طرف جديد'
                      : 'تعديل بيانات الطرف',
                ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطرف *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: addressController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: openingReceivableController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'رصيد أول المدة - لنا',
                        prefixIcon: Icon(Icons.arrow_downward),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: openingPayableController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'رصيد أول المدة - علينا',
                        prefixIcon: Icon(Icons.arrow_upward),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال اسم الطرف'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final receivable = double.tryParse(
                                openingReceivableController.text
                                    .trim()
                                    .replaceAll(',', ''),
                              ) ??
                              0.0;

                          final payable = double.tryParse(
                                openingPayableController.text
                                    .trim()
                                    .replaceAll(',', ''),
                              ) ??
                              0.0;

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final id = existing?.id ?? uuid.v4();

                            final data = {
                              'id': id,
                              'name': name,
                              'phone': phoneController.text.trim(),
                              'address': addressController.text.trim(),
                              'notes': notesController.text.trim(),
                              'opening_receivable': receivable,
                              'opening_payable': payable,
                            };

                            if (existing == null) {
                              await supabase
                                  .from('persons')
                                  .insert(data);
                            } else {
                              await supabase
                                  .from('persons')
                                  .update(data)
                                  .eq('id', existing.id);
                            }

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext, true);
                          } catch (e, stackTrace) {
                            debugPrint('Save person error: $e');
                            debugPrintStack(
                              stackTrace: stackTrace,
                            );

                            setDialogState(() {
                              saving = false;
                            });

                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تعذر حفظ البيانات:\n${_friendlySupabaseError(e)}',
                                  textDirection: TextDirection.rtl,
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    saving ? 'جارٍ الحفظ...' : 'حفظ',
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    openingReceivableController.dispose();
    openingPayableController.dispose();

    if (result == true && mounted) {
      await _loadData();

      _showSuccess(
        existing == null
            ? 'تمت إضافة الطرف بنجاح'
            : 'تم تعديل بيانات الطرف بنجاح',
      );
    }
  }

  Future<void> _handleDeletePerson(PersonModel person) async {
    final authorized = await SettingsScreen.verifyPassword(context);

    if (!authorized || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف الطرف:\n\n${person.name}؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await supabase
          .from('persons')
          .delete()
          .eq('id', person.id);

      await _loadData();

      _showSuccess('تم حذف الطرف بنجاح');
    } catch (e, stackTrace) {
      debugPrint('Delete person error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showError(
        'تعذر حذف الطرف:\n${_friendlySupabaseError(e)}',
      );
    }
  }

  double _personBalance(PersonModel person) {
    try {
      final events = AccountingEngine.calculateStatement(
        person,
        _trips,
        _payments,
      );

      if (events.isEmpty) {
        return person.openingReceivable - person.openingPayable;
      }

      final lastBalance =
          (events.last['balance'] as num?)?.toDouble() ?? 0.0;

      return lastBalance;
    } catch (e) {
      debugPrint(
        'Calculate balance error for ${person.name}: $e',
      );

      return person.openingReceivable - person.openingPayable;
    }
  }

  Widget _buildPersonCard(PersonModel person) {
    final balance = _personBalance(person);

    final isReceivable = balance > 0;
    final isPayable = balance < 0;

    String balanceText;

    if (balance.abs() < 0.01) {
      balanceText = 'متزن';
    } else if (isReceivable) {
      balanceText =
          'لنا: ${balance.abs().toStringAsFixed(2)} ج.م';
    } else {
      balanceText =
          'علينا: ${balance.abs().toStringAsFixed(2)} ج.م';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          radius: 25,
          child: Text(
            person.name.isNotEmpty
                ? person.name.characters.first
                : '?',
            style: const TextStyle(
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (person.phone.isNotEmpty)
              Text('📞 ${person.phone}'),
            const SizedBox(height: 3),
            Text(
              balanceText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isReceivable
                    ? Colors.green.shade700
                    : isPayable
                        ? Colors.red.shade700
                        : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'statement') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatementScreen(
                    initialPerson: person,
                  ),
                ),
              );
            } else if (value == 'edit') {
              _handleEditPerson(person);
            } else if (value == 'delete') {
              _handleDeletePerson(person);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'statement',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('كشف الحساب'),
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('تعديل'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: Text('حذف'),
              ),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persons = _filteredPersons;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأطراف'),
          actions: [
            IconButton(
              onPressed: _loadData,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _handleAddPerson,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة طرف'),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _search = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'بحث عن طرف...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    _search = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: persons.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'لا توجد أطراف',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                90,
                              ),
                              itemCount: persons.length,
                              itemBuilder: (context, index) {
                                return _buildPersonCard(
                                  persons[index],
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
