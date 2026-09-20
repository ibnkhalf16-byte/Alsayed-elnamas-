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
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPersonsAndCalculateBalances();
  }

  // ============================================================
  // تحميل الأطراف وحساب الأرصدة
  // ============================================================
  Future<void> _loadPersonsAndCalculateBalances() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;

      debugPrint('========== SUPABASE LOAD PERSONS ==========');

      final personsData = await supabase
          .from('persons')
          .select();

      debugPrint(
        'Persons loaded successfully: ${personsData.length}',
      );

      final tripsData = await supabase
          .from('trips')
          .select();

      debugPrint(
        'Trips loaded successfully: ${tripsData.length}',
      );

      final paymentsData = await supabase
          .from('payments')
          .select();

      debugPrint(
        'Payments loaded successfully: ${paymentsData.length}',
      );

      final List<PersonModel> persons = personsData
          .map(
            (e) => PersonModel.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      final List<TripModel> allTrips = tripsData
          .map(
            (e) => TripModel.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      final List<PaymentModel> allPayments = paymentsData
          .map(
            (e) => PaymentModel.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
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
          actualBalance =
              person.openingReceivable - person.openingPayable;
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
          _filteredPersons = computedList.where((p) {
            final person = p['person'] as PersonModel;

            return person.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();
        } else {
          _filteredPersons = computedList;
        }

        _isLoading = false;
      });

      debugPrint(
        'Persons displayed: ${computedList.length}',
      );

      debugPrint(
        '============================================',
      );
    } catch (e, stackTrace) {
      debugPrint('========== SUPABASE LOAD ERROR ==========');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint('=========================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _personsWithBalances = [];
        _filteredPersons = [];
      });

      _showError(
        'تعذر تحميل البيانات من قاعدة البيانات.\n\n${_friendlySupabaseError(e)}',
      );
    }
  }

  // ============================================================
  // فلترة البحث
  // ============================================================
  void _filterPersons(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    setState(() {
      _searchQuery = query;

      _filteredPersons = _personsWithBalances.where((p) {
        final person = p['person'] as PersonModel;

        return person.name
            .toLowerCase()
            .contains(normalizedQuery);
      }).toList();
    });
  }

  // ============================================================
  // إضافة / تعديل طرف
  // ============================================================
  void openPersonDialog({PersonModel? existing}) {
    final isEdit = existing != null;

    final formKey = GlobalKey<FormState>();

    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');

    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');

    final addressCtrl =
        TextEditingController(text: existing?.address ?? '');

    final recCtrl = TextEditingController(
      text: existing != null
          ? existing.openingReceivable.toString()
          : '0',
    );

    final payCtrl = TextEditingController(
      text: existing != null
          ? existing.openingPayable.toString()
          : '0',
    );

    bool dialogSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePerson() async {
              if (dialogSaving) return;

              FocusScope.of(context).unfocus();

              if (!formKey.currentState!.validate()) {
                return;
              }

              final rec =
                  double.tryParse(recCtrl.text.trim()) ?? 0.0;

              final pay =
                  double.tryParse(payCtrl.text.trim()) ?? 0.0;

              if (rec < 0 || pay < 0) {
                _showError(
                  'لا يمكن إدخال قيمة سالبة في رصيد أول المدة.',
                );
                return;
              }

              if (rec > 0 && pay > 0) {
                _showError(
                  'الرجاء إدخال رصيد في جهة واحدة فقط:\n'
                  'إما "لك عنده" أو "له عندك".',
                );
                return;
              }

              setDialogState(() {
                dialogSaving = true;
              });

              try {
                final supabase =
                    Supabase.instance.client;

                final personName =
                    nameCtrl.text.trim();

                final personPhone =
                    phoneCtrl.text.trim();

                final personAddress =
                    addressCtrl.text.trim();

                if (isEdit) {
                  final updated = PersonModel(
                    id: existing.id,
                    name: personName,
                    phone: personPhone,
                    address: personAddress,
                    openingReceivable: rec,
                    openingPayable: pay,
                  );

                  debugPrint(
                    'Updating person: ${existing.id}',
                  );

                  await supabase
                      .from('persons')
                      .update(updated.toMap())
                      .eq('id', existing.id);

                  debugPrint(
                    'Person updated successfully',
                  );
                } else {
                  final newP = PersonModel(
                    id: const Uuid().v4(),
                    name: personName,
                    phone: personPhone,
                    address: personAddress,
                    openingReceivable: rec,
                    openingPayable: pay,
                  );

                  debugPrint(
                    'Inserting new person: ${newP.id}',
                  );

                  await supabase
                      .from('persons')
                      .insert(newP.toMap());

                  debugPrint(
                    'Person inserted successfully',
                  );
                }

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'تم تعديل بيانات الطرف بنجاح'
                          : 'تم إضافة الطرف بنجاح',
                    ),
                    backgroundColor:
                        const Color(0xFF10B981),
                  ),
                );

                await _loadPersonsAndCalculateBalances();
              } catch (e, stackTrace) {
                debugPrint(
                  '========== SAVE PERSON ERROR =========='
                );

                debugPrint(e.toString());
                debugPrint(stackTrace.toString());

                debugPrint(
                  '=======================================',
                );

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  dialogSaving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      _friendlySupabaseError(e),
                    ),
                    backgroundColor:
                        const Color(0xFFEF4444),
                    duration:
                        const Duration(seconds: 5),
                  ),
                );
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                title: Text(
                  isEdit
                      ? 'تعديل بيانات طرف'
                      : 'إضافة طرف جديد (عميل / مورد)',
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          enabled: !dialogSaving,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'الاسم بالكامل',
                          ),
                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'الاسم مطلوب';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: phoneCtrl,
                          enabled: !dialogSaving,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'رقم الهاتف',
                          ),
                          keyboardType:
                              TextInputType.phone,
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: addressCtrl,
                          enabled: !dialogSaving,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'العنوان أو المركز',
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'رصيد أول المدة',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: recCtrl,
                          enabled: !dialogSaving,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'لك عنده (المبلغ الذي يدين لك به)',
                            labelStyle: TextStyle(
                              color:
                                  Color(0xFF10B981),
                              fontWeight:
                                  FontWeight.bold,
                            ),
                            prefixIcon: Icon(
                              Icons.arrow_downward,
                              color:
                                  Color(0xFF10B981),
                            ),
                          ),
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final val =
                                double.tryParse(
                              v ?? '0',
                            );

                            if (val != null &&
                                val < 0) {
                              return 'لا يمكن إدخال قيمة سالبة';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: payCtrl,
                          enabled: !dialogSaving,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'له عندك (المبلغ الذي تدين له به)',
                            labelStyle: TextStyle(
                              color:
                                  Color(0xFFEF4444),
                              fontWeight:
                                  FontWeight.bold,
                            ),
                            prefixIcon: Icon(
                              Icons.arrow_upward,
                              color:
                                  Color(0xFFEF4444),
                            ),
                          ),
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final val =
                                double.tryParse(
                              v ?? '0',
                            );

                            if (val != null &&
                                val < 0) {
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
                    onPressed: dialogSaving
                        ? null
                        : () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                    child: const Text('إلغاء'),
                  ),

                  ElevatedButton(
                    onPressed:
                        dialogSaving ? null : savePerson,
                    child: dialogSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // حذف طرف
  // ============================================================
  Future<void> _deletePerson(
    PersonModel person,
  ) async {
    try {
      final supabase =
          Supabase.instance.client;

      await supabase
          .from('persons')
          .delete()
          .eq('id', person.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الطرف بنجاح'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      await _loadPersonsAndCalculateBalances();
    } catch (e, stackTrace) {
      debugPrint(
        'DELETE PERSON ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      _showError(
        'تعذر حذف الطرف.\n\n${_friendlySupabaseError(e)}',
      );
    }
  }

  // ============================================================
  // رسائل الخطأ
  // ============================================================
  String _friendlySupabaseError(Object error) {
    final message = error.toString();

    if (message.contains('Failed host lookup') ||
        message.contains('SocketException')) {
      return 'تعذر الاتصال بخادم Supabase.\n'
          'تأكد من اتصال الإنترنت وإعدادات Supabase.';
    }

    if (message.contains('permission denied') ||
        message.contains('42501') ||
        message.contains('row-level security')) {
      return 'تم رفض العملية من Supabase.\n'
          'تحقق من صلاحيات RLS للجدول.';
    }

    if (message.contains('PGRST116')) {
      return 'لم يتم العثور على البيانات المطلوبة.';
    }

    if (message.contains('duplicate key')) {
      return 'هذه البيانات موجودة بالفعل.';
    }

    if (message.contains('violates foreign key')) {
      return 'لا يمكن تنفيذ العملية لأن هناك بيانات مرتبطة بهذا الطرف.';
    }

    return message;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ============================================================
  // الواجهة
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          'دليل العملاء والموردين',
        ),
        backgroundColor:
            const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _isLoading
                ? null
                : _loadPersonsAndCalculateBalances,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E3A8A),
            padding:
                const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),
            child: Directionality(
              textDirection:
                  TextDirection.rtl,
              child: TextField(
                onChanged: _filterPersons,
                decoration:
                    InputDecoration(
                  hintText:
                      'ابحث باسم الطرف...',
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _filteredPersons.isEmpty
                    ? Center(
                        child:
                            Directionality(
                          textDirection:
                              TextDirection.rtl,
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons
                                    .people_outline,
                                size: 60,
                                color:
                                    Colors.grey,
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              const Text(
                                'لا يوجد أطراف مسجلة أو مطابقة للبحث',
                                style:
                                    TextStyle(
                                  fontSize: 16,
                                ),
                                textAlign:
                                    TextAlign.center,
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _loadPersonsAndCalculateBalances,
                                icon:
                                    const Icon(
                                  Icons.refresh,
                                ),
                                label:
                                    const Text(
                                  'تحديث البيانات',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        itemCount:
                            _filteredPersons.length,
                        itemBuilder:
                            (context, index) {
                          final data =
                              _filteredPersons[
                                  index];

                          final PersonModel
                              person =
                              data['person']
                                  as PersonModel;

                          final double
                              balance =
                              (data[
                                      'actual_balance']
                                  as num)
                                  .toDouble();

                          final bool
                              isOwedToYou =
                              balance > 0;

                          final bool
                              isOwedByYou =
                              balance < 0;

                          Color statusColor =
                              Colors.grey;

                          String statusText =
                              'رصيد مصفر';

                          if (isOwedToYou) {
                            statusColor =
                                const Color(
                              0xFF10B981,
                            );

                            statusText =
                                'مستحق لك عنده';
                          } else if (isOwedByYou) {
                            statusColor =
                                const Color(
                              0xFFEF4444,
                            );

                            statusText =
                                'مطلوب له عندك';
                          }

                          return Directionality(
                            textDirection:
                                TextDirection.rtl,
                            child: Card(
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 12,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                                side:
                                    BorderSide(
                                  color: statusColor
                                      .withOpacity(
                                    0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              elevation: 0,
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),

                                leading:
                                    CircleAvatar(
                                  backgroundColor:
                                      statusColor
                                          .withOpacity(
                                    0.1,
                                  ),
                                  child: Text(
                                    person.name
                                            .isNotEmpty
                                        ? person
                                            .name
                                            .substring(
                                            0,
                                            1,
                                          )
                                        : '?',
                                    style:
                                        TextStyle(
                                      color:
                                          statusColor,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),

                                title: Text(
                                  person.name,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    fontSize: 16,
                                  ),
                                ),

                                subtitle:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        statusText,
                                        style:
                                            TextStyle(
                                          color:
                                              statusColor,
                                          fontSize:
                                              12,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      Text(
                                        '${balance.abs().toStringAsFixed(2)} ج.م',
                                        style:
                                            TextStyle(
                                          color:
                                              statusColor,
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                trailing:
                                    PopupMenuButton<
                                        String>(
                                  icon:
                                      const Icon(
                                    Icons.more_vert,
                                  ),
                                  onSelected:
                                      (val) async {
                                    if (val ==
                                        'edit') {
                                      openPersonDialog(
                                        existing:
                                            person,
                                      );
                                    } else if (val ==
                                        'delete') {
                                      await _deletePerson(
                                        person,
                                      );
                                    }
                                  },
                                  itemBuilder:
                                      (ctx) => [
                                    const PopupMenuItem(
                                      value:
                                          'edit',
                                      child:
                                          Text(
                                        'تعديل البيانات',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value:
                                          'delete',
                                      child:
                                          Text(
                                        'حذف الطرف',
                                        style:
                                            TextStyle(
                                          color:
                                              Color(
                                            0xFFEF4444,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              StatementScreen(
                                        initialPerson:
                                            person,
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

      floatingActionButton:
          Directionality(
        textDirection:
            TextDirection.rtl,
        child:
            FloatingActionButton.extended(
          onPressed:
              () => openPersonDialog(),
          backgroundColor:
              const Color(0xFF1E3A8A),
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
