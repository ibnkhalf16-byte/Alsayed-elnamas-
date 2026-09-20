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

        double actualBalance;

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

        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim().toLowerCase();

          _filteredPersons = computedList.where((p) {
            final person = p['person'] as PersonModel;

            return person.name
                .toLowerCase()
                .contains(query);
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
        'تعذر تحميل البيانات من قاعدة البيانات.\n\n'
        '${_friendlySupabaseError(e)}',
      );
    }
  }

  // ============================================================
  // البحث
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
  Future<void> openPersonDialog({
    PersonModel? existing,
  }) async {
    final isEdit = existing != null;

    // ------------------------------------------------------------
    // حماية العمليات الحساسة
    // ------------------------------------------------------------
    final authorized = await SettingsScreen.verifyPassword(context);

    if (!authorized) {
      return;
    }

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();

    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');

    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');

    final addressCtrl =
        TextEditingController(text: existing?.address ?? '');

    final notesCtrl =
        TextEditingController(text: existing?.notes ?? '');

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

    await showDialog(
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
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'لا يمكن إدخال قيمة سالبة في رصيد أول المدة.',
                    ),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }

              if (rec > 0 && pay > 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'الرجاء إدخال رصيد في جهة واحدة فقط:\n'
                      'إما "لك عنده" أو "له عندك".',
                    ),
                    backgroundColor: Color(0xFFEF4444),
                  ),
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

                final personNotes =
                    notesCtrl.text.trim();

                if (isEdit) {
                  final updated = PersonModel(
                    id: existing.id,
                    name: personName,
                    phone: personPhone,
                    address: personAddress,
                    notes: personNotes,
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
                    notes: personNotes,
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
                  '========== SAVE PERSON ERROR ==========',
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

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: notesCtrl,
                          enabled: !dialogSaving,
                          maxLines: 2,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'ملاحظات',
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

    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    notesCtrl.dispose();
    recCtrl.dispose();
    payCtrl.dispose();
  }

  // ============================================================
  // حذف طرف
  // ============================================================
  Future<void> _deletePerson(
    PersonModel person,
  ) async {
    final authorized =
        await SettingsScreen.verifyPassword(context);

    if (!authorized) {
      return;
    }

    if (!mounted) return;

    // ------------------------------------------------------------
    // تأكيد إضافي قبل الحذف
    // ------------------------------------------------------------
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(width: 8),
                Text('تأكيد الحذف'),
              ],
            ),
            content: Text(
              'هل أنت متأكد من حذف الطرف:\n\n'
              '${person.name}\n\n'
              'سيتم حذف بيانات الطرف فقط.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: () =>
                    Navigator.pop(ctx, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

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
        'تعذر حذف الطرف.\n\n'
        '${_friendlySupabaseError(e)}',
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
                                      await openPersonDialog(
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

تنبيه صغير: في الكود أعلاه يوجد خطأ مطبعي محتمل في "Navigator.push(...).then" إذا نسخته حرفيًا بسبب تنسيق القوس. الأفضل أن يكون هذا الجزء تحديدًا:

onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StatementScreen(
        initialPerson: person,
      ),
    ),
  ).then(
    (_) => _loadPersonsAndCalculateBalances(),
  );
},

2. "statement_screen.dart"

:::writing{variant="document" id="62417" title="StatementScreen كامل مع إصلاح زر PDF والرصيد الافتتاحي"}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/accounting/accounting_engine.dart';
import '../../core/pdf/pdf_generator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';

class StatementScreen extends StatefulWidget {
  final PersonModel? initialPerson;

  const StatementScreen({
    Key? key,
    this.initialPerson,
  }) : super(key: key);

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  List<PersonModel> _persons = [];
  PersonModel? _selectedPerson;
  List<Map<String, dynamic>> _events = [];

  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final supabase = Supabase.instance.client;

      final maps = await supabase
          .from('persons')
          .select()
          .order('name', ascending: true);

      final pList = maps
          .map(
            (m) => PersonModel.fromMap(
              Map<String, dynamic>.from(m),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _persons = pList;
        _isLoading = false;

        if (widget.initialPerson != null) {
          _selectedPerson = _persons.firstWhere(
            (p) => p.id == widget.initialPerson!.id,
            orElse: () => widget.initialPerson!,
          );
        }
      });

      if (_selectedPerson != null) {
        await _fetchStatement(_selectedPerson!);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطأ في جلب الأطراف:\n$e',
          ),
          backgroundColor: AppColors.payableRed,
        ),
      );
    }
  }

  Future<void> _fetchStatement(
    PersonModel person,
  ) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;

      final tMaps =
          await supabase.from('trips').select();

      final pMaps =
          await supabase.from('payments').select();

      final trips = tMaps
          .map(
            (m) => TripModel.fromMap(
              Map<String, dynamic>.from(m),
            ),
          )
          .toList();

      final payments = pMaps
          .map(
            (m) => PaymentModel.fromMap(
              Map<String, dynamic>.from(m),
            ),
          )
          .toList();

      final statementEvents =
          AccountingEngine.calculateStatement(
        person,
        trips,
        payments,
      );

      if (!mounted) return;

      setState(() {
        _selectedPerson = person;
        _events = statementEvents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطأ في جلب الحركات:\n$e',
          ),
          backgroundColor: AppColors.payableRed,
        ),
      );
    }
  }

  // ============================================================
  // حساب الرصيد النهائي
  // ============================================================
  double _getLastBalance() {
    if (_events.isNotEmpty) {
      return (_events.last['balance'] as num?)?.toDouble() ?? 0.0;
    }

    if (_selectedPerson != null) {
      return _selectedPerson!.openingReceivable -
          _selectedPerson!.openingPayable;
    }

    return 0.0;
  }

  // ============================================================
  // PDF
  // ============================================================
  Future<void> _generatePdf() async {
    if (_selectedPerson == null) {
      return;
    }

    if (_isGeneratingPdf) {
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      await PdfGenerator.generateAndPrintStatement(
        person: _selectedPerson!,
        events: _events,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '========== PDF ERROR ==========',
      );
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint(
        '==============================',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إنشاء ملف PDF.\n\n$e',
          ),
          backgroundColor: AppColors.payableRed,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastBalance = _getLastBalance();
    final isReceivable = lastBalance >= 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'كشف حساب مفصل',
          ),
          actions: [
            if (_selectedPerson != null)
              IconButton(
                tooltip: 'تصدير PDF',
                onPressed:
                    _isGeneratingPdf ? null : _generatePdf,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.picture_as_pdf_outlined,
                      ),
              ),
          ],
        ),

        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(16.0),
              child:
                  DropdownButtonFormField<PersonModel>(
                value: _selectedPerson,
                decoration:
                    const InputDecoration(
                  labelText:
                      'اختر الطرف (العميل أو المورد)',
                  prefixIcon:
                      Icon(Icons.person),
                ),
                items: _persons
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  if (p != null) {
                    _fetchStatement(p);
                  }
                },
              ),
            ),

            if (_selectedPerson != null)
              Container(
                margin:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                padding:
                    const EdgeInsets.all(16),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: isReceivable
                        ? [
                            AppColors
                                .receivableGreen
                                .withOpacity(0.8),
                            AppColors
                                .receivableGreen,
                          ]
                        : [
                            AppColors
                                .payableRed
                                .withOpacity(0.8),
                            AppColors.payableRed,
                          ],
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isReceivable
                                  ? AppColors
                                      .receivableGreen
                                  : AppColors
                                      .payableRed)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      offset:
                          const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'الرصيد النهائي الحالي:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          AppFormatters
                              .formatCurrency(
                            lastBalance.abs(),
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Text(
                        isReceivable
                            ? 'مستحق (لك عنده)'
                            : 'مطلوب (له عندك)',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _events.isEmpty
                      ? Center(
                          child: Text(
                            _selectedPerson == null
                                ? 'اختر طرفًا لعرض كشف الحساب'
                                : 'لا توجد حركات مسجلة لهذا الحساب',
                            style:
                                const TextStyle(
                              color:
                                  AppColors
                                      .textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount:
                              _events.length,
                          itemBuilder:
                              (ctx, i) {
                            final ev =
                                _events[i];

                            final debit =
                                (ev['debit']
                                            as num?)
                                        ?.toDouble() ??
                                    0.0;

                            final credit =
                                (ev['credit']
                                            as num?)
                                        ?.toDouble() ??
                                    0.0;

                            final balance =
                                (ev['balance']
                                            as num?)
                                        ?.toDouble() ??
                                    0.0;

                            final isOpening =
                                ev['type'] ==
                                    'رصيد افتتاح';

                            return Card(
                              elevation: 1,
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 12,
                              ),
                              color: isOpening
                                  ? AppColors
                                      .primary
                                      .withOpacity(
                                      0.05,
                                    )
                                  : Colors.white,
                              child: Padding(
                                padding:
                                    const EdgeInsets
                                        .all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isOpening
                                                  ? Icons
                                                      .account_balance
                                                  : (debit >
                                                          0
                                                      ? Icons
                                                          .add_circle
                                                      : Icons
                                                          .remove_circle),
                                              color: isOpening
                                                  ? AppColors
                                                      .primary
                                                  : (debit >
                                                          0
                                                      ? AppColors
                                                          .receivableGreen
                                                      : AppColors
                                                          .payableRed),
                                              size: 20,
                                            ),
                                            const SizedBox(
                                              width: 8,
                                            ),
                                            Text(
                                              '${ev['type']}',
                                              style:
                                                  TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize:
                                                    15,
                                                color: isOpening
                                                    ? AppColors
                                                        .primary
                                                    : AppColors
                                                        .textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          ev['date']
                                              .toString(),
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                13,
                                            color:
                                                AppColors
                                                    .textSecondary,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Text(
                                      'البيان: ${ev['desc'] ?? ''}',
                                      style:
                                          const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),

                                    const Divider(
                                      height: 24,
                                    ),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              'مدين (+): ${AppFormatters.formatCurrency(debit)}',
                                              style:
                                                  const TextStyle(
                                                color: AppColors
                                                    .receivableGreen,
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'دائن (-): ${AppFormatters.formatCurrency(credit)}',
                                              style:
                                                  const TextStyle(
                                                color: AppColors
                                                    .payableRed,
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal:
                                                12,
                                            vertical:
                                                6,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: AppColors
                                                .scaffoldBackground,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              8,
                                            ),
                                          ),
                                          child:
                                              Text(
                                            'الرصيد: ${AppFormatters.formatCurrency(balance)}',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize:
                                                  14,
                                              color: AppColors
                                                  .primaryDark,
                                            ),
                                          ),
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
          ],
        ),
      ),
    );
  }
}

3. "pdf_generator.dart"

:::writing{variant="document" id="73146" title="PdfGenerator كامل بعد إصلاح PDF"}

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/person_model.dart';

class PdfGenerator {
  static Future<void> generateAndPrintStatement({
    required PersonModel person,
    required List<Map<String, dynamic>> events,
  }) async {
    try {
      final pdf = pw.Document();

      // ==========================================================
      // تحميل الخط العربي
      // ==========================================================
      final regularFontData = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Regular.ttf',
      );

      final boldFontData = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Bold.ttf',
      );

      final fontRegular =
          pw.Font.ttf(regularFontData);

      final fontBold =
          pw.Font.ttf(boldFontData);

      // ==========================================================
      // الرصيد النهائي
      // ==========================================================
      double lastBalance;

      if (events.isNotEmpty) {
        lastBalance =
            (events.last['balance'] as num?)
                    ?.toDouble() ??
                0.0;
      } else {
        lastBalance =
            person.openingReceivable -
                person.openingPayable;
      }

      // ==========================================================
      // تاريخ الطباعة
      // ==========================================================
      final now = DateTime.now();

      final currentDateStr =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      // ==========================================================
      // إذا لم توجد حركات، ننشئ صف الرصيد الافتتاحي للـPDF
      // ==========================================================
      final List<Map<String, dynamic>> pdfEvents =
          List<Map<String, dynamic>>.from(events);

      if (pdfEvents.isEmpty &&
          (person.openingReceivable != 0 ||
              person.openingPayable != 0)) {
        final openingBalance =
            person.openingReceivable -
                person.openingPayable;

        pdfEvents.add({
          'date': 'رصيد افتتاح',
          'type': 'رصيد افتتاح',
          'desc': 'رصيد أول المدة',
          'vehicle': '',
          'driver': '',
          'weight': 0.0,
          'price': 0.0,
          'debit': person.openingReceivable,
          'credit': person.openingPayable,
          'balance': openingBalance,
        });
      }

      // ==========================================================
      // إنشاء الصفحة
      // ==========================================================
      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat.a4.landscape,

          textDirection:
              pw.TextDirection.rtl,

          margin:
              const pw.EdgeInsets.only(
            left: 18,
            right: 18,
            top: 15,
            bottom: 18,
          ),

          theme:
              pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
          ),

          // ======================================================
          // رأس الصفحة
          // ======================================================
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment
                      .stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    'حسابات علاء ابو شادي',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 19,
                      color:
                          PdfColors.blueGrey900,
                    ),
                  ),
                ),

                pw.SizedBox(height: 5),

                pw.Container(
                  alignment:
                      pw.Alignment.centerRight,
                  child: pw.Text(
                    'كشف حساب: ${person.name}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                  ),
                ),

                if (person.phone.isNotEmpty)
                  pw.Container(
                    alignment:
                        pw.Alignment.centerRight,
                    child: pw.Text(
                      'الهاتف: ${person.phone}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color:
                            PdfColors.grey700,
                      ),
                    ),
                  ),

                pw.SizedBox(height: 7),
              ],
            );
          },

          // ======================================================
          // التذييل
          // ======================================================
          footer: (pw.Context context) {
            return pw.Column(
              children: [
                pw.SizedBox(height: 8),

                pw.Divider(
                  color:
                      PdfColors.grey400,
                  thickness: 0.5,
                ),

                pw.SizedBox(height: 5),

                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment
                          .spaceBetween,
                  children: [
                    pw.Text(
                      'صفحة ${context.pageNumber} من ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color:
                            PdfColors.grey700,
                      ),
                    ),

                    pw.Text(
                      'تم تصميم البرنامج بواسطة علي خلف',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color:
                            PdfColors.blueGrey900,
                      ),
                    ),

                    pw.Text(
                      'تاريخ الطباعة: $currentDateStr',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color:
                            PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },

          // ======================================================
          // الجدول
          // ======================================================
          build: (pw.Context context) => [
            pw.TableHelper.fromTextArray(
              context: context,

              border:
                  pw.TableBorder.all(
                color:
                    PdfColors.grey500,
                width: 0.5,
              ),

              headerStyle:
                  pw.TextStyle(
                font: fontBold,
                fontSize: 9,
                color:
                    PdfColors.white,
              ),

              headerDecoration:
                  const pw.BoxDecoration(
                color:
                    PdfColor.fromInt(
                  0xFF1E3A8A,
                ),
              ),

              headerHeight: 25,

              cellStyle:
                  pw.TextStyle(
                font: fontRegular,
                fontSize: 8.5,
              ),

              cellHeight: 22,

              cellAlignment:
                  pw.Alignment.center,

              columnWidths: const {
                0: pw.FlexColumnWidth(2.1),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(2.6),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(2.1),
                5: pw.FlexColumnWidth(1.2),
                6: pw.FlexColumnWidth(1.7),
                7: pw.FlexColumnWidth(2.0),
                8: pw.FlexColumnWidth(2.0),
                9: pw.FlexColumnWidth(2.3),
              },

              headers: <String>[
                'التاريخ',
                'الحركة',
                'البيان',
                'التحميل',
                'السائق',
                'طن',
                'سعر الطن',
                'مدين',
                'دائن',
                'الرصيد',
              ],

              data: pdfEvents.map((ev) {
                final debit =
                    (ev['debit'] as num?)
                            ?.toDouble() ??
                        0.0;

                final credit =
                    (ev['credit'] as num?)
                            ?.toDouble() ??
                        0.0;

                final balance =
                    (ev['balance'] as num?)
                            ?.toDouble() ??
                        0.0;

                final weight =
                    (ev['weight'] as num?)
                            ?.toDouble() ??
                        0.0;

                final price =
                    (ev['price'] as num?)
                            ?.toDouble() ??
                        0.0;

                final vehicle =
                    (ev['vehicle'] ?? '')
                        .toString();

                final driver =
                    (ev['driver'] ?? '')
                        .toString();

                final itemOrDesc =
                    (ev['desc'] ?? '')
                        .toString();

                final actionType =
                    (ev['type'] ?? '')
                        .toString();

                final date =
                    ev['date']
                            ?.toString() ??
                        '';

                return [
                  date,
                  actionType,
                  itemOrDesc,
                  vehicle,
                  driver,
                  weight > 0
                      ? weight.toStringAsFixed(2)
                      : '',
                  price > 0
                      ? price.toStringAsFixed(2)
                      : '',
                  debit > 0
                      ? debit.toStringAsFixed(2)
                      : '0.00',
                  credit > 0
                      ? credit.toStringAsFixed(2)
                      : '0.00',
                  balance.toStringAsFixed(2),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 12),

            // ====================================================
            // الرصيد النهائي
            // ====================================================
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.start,
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration:
                      pw.BoxDecoration(
                    border:
                        pw.Border.all(
                      color:
                          PdfColors
                              .blueGrey800,
                      width: 1,
                    ),
                    borderRadius:
                        const pw.BorderRadius
                            .all(
                      pw.Radius.circular(4),
                    ),
                    color:
                        PdfColors.grey100,
                  ),
                  child: pw.Text(
                    'الرصيد النهائي: '
                    '${lastBalance.toStringAsFixed(2)} ج.م',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color:
                          PdfColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      debugPrint(
        'Generating PDF for ${person.name}',
      );

      await Printing.layoutPdf(
        onLayout:
            (PdfPageFormat format) async {
          return pdf.save();
        },
        name:
            'كشف_حساب_${person.name}',
        format:
            PdfPageFormat.a4.landscape,
      );

      debugPrint(
        'PDF generated successfully',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '========== PDF GENERATOR ERROR ==========',
      );
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint(
        '=========================================',
      );

      rethrow;
    }
  }
}

