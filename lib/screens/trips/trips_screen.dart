import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/accounting/accounting_engine.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/trip_model.dart';
import '../../models/person_model.dart';
import '../settings/settings_screen.dart';

class TripsScreen extends StatefulWidget {
  final String? initialOperation;

  const TripsScreen({
    Key? key,
    this.initialOperation,
  }) : super(key: key);

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

  // ============================================================
  // تحميل البيانات
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final supabase = Supabase.instance.client;

      final pMaps = await supabase
          .from('persons')
          .select()
          .order('name', ascending: true);

      final rawTrips = await supabase
          .from('trips')
          .select()
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      final personNames = {
        for (final p in pMaps)
          p['id'].toString(): p['name']?.toString() ?? 'غير معروف',
      };

      final tMaps = rawTrips.map((t) {
        final mutableTrip = Map<String, dynamic>.from(t);

        mutableTrip['person_name'] =
            personNames[t['person_id']?.toString()] ?? 'غير معروف';

        return mutableTrip;
      }).toList();

      final personsList = pMaps
          .map((m) => PersonModel.fromMap(m))
          .toList();

      final tripsList = tMaps
          .map((m) => TripModel.fromMap(m))
          .toList();

      final statusesMap =
          AccountingEngine.calculateTripStatuses(tripsList);

      if (!mounted) return;

      setState(() {
        _persons = personsList;
        _trips = tripsList;
        _statuses = statusesMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showError(
        'تعذر تحميل النقلات',
        e,
      );
    }
  }

  // ============================================================
  // عرض رسالة خطأ
  // ============================================================

  void _showError(String title, Object error) {
    if (!mounted) return;

    String message = error.toString();

    if (error is PostgrestException) {
      message = error.message;

      if (error.code == '42501') {
        message =
            'تم رفض العملية من قاعدة البيانات بسبب صلاحيات RLS.\n'
            'تأكد من وجود سياسة INSERT / UPDATE على جدول trips.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: AppColors.payableRed,
        content: Text(
          '$title\n$message',
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  // ============================================================
  // نافذة إضافة / تعديل نقلة
  // ============================================================

  void openTripDialog({
    TripModel? existing,
    String? preselectedOperation,
  }) {
    final isEdit = existing != null;

    final formKey = GlobalKey<FormState>();

    String? selectedPerson = existing?.personId;

    String operation = existing?.operation ??
        (preselectedOperation ??
            widget.initialOperation ??
            'purchase');

    final bool isOperationLocked =
        preselectedOperation != null ||
        widget.initialOperation != null ||
        existing != null;

    DateTime selectedDate = existing != null
        ? (DateTime.tryParse(existing.date) ?? DateTime.now())
        : DateTime.now();

    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    final carCtrl = TextEditingController(
      text: existing?.vehicle ?? '',
    );

    final driverCtrl = TextEditingController(
      text: existing?.driver ?? '',
    );

    final itemCtrl = TextEditingController(
      text: existing?.item ?? '',
    );

    final weightCtrl = TextEditingController(
      text: existing != null
          ? existing.weight.toString()
          : '',
    );

    final priceCtrl = TextEditingController(
      text: existing != null
          ? existing.price.toString()
          : '',
    );

    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            Future<void> saveTrip() async {
              // منع الضغط مرتين
              if (isSaving) return;

              // التحقق من الحقول
              if (!formKey.currentState!.validate()) {
                return;
              }

              if (selectedPerson == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى اختيار الطرف'),
                  ),
                );
                return;
              }

              final weight =
                  double.tryParse(weightCtrl.text.trim());

              final price =
                  double.tryParse(priceCtrl.text.trim());

              if (weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الوزن غير صحيح'),
                  ),
                );
                return;
              }

              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سعر الطن غير صحيح'),
                  ),
                );
                return;
              }

              // ==================================================
              // حماية الإضافة والتعديل
              // ==================================================

              final isAuthorized =
                  await SettingsScreen.verifyPassword(context);

              if (!isAuthorized) {
                return;
              }

              if (!mounted) return;

              setModalState(() {
                isSaving = true;
              });

              try {
                final supabase =
                    Supabase.instance.client;

                final total = weight * price;

                if (isEdit) {
                  // ==================================================
                  // تعديل النقلة
                  // ==================================================

                  final updated = TripModel(
                    id: existing.id,
                    personId: selectedPerson!,
                    operation: operation,
                    date: dateCtrl.text.trim(),
                    vehicle: carCtrl.text.trim(),
                    driver: driverCtrl.text.trim(),
                    item: itemCtrl.text.trim(),
                    weight: weight,
                    price: price,
                    total: total,
                    notes: notesCtrl.text.trim(),
                    sourceTripId: existing.sourceTripId,
                  );

                  await supabase
                      .from('trips')
                      .update(updated.toMap())
                      .eq('id', existing.id);
                } else {
                  // ==================================================
                  // إضافة نقلة جديدة
                  // ==================================================

                  final newTrip = TripModel(
                    id: const Uuid().v4(),
                    personId: selectedPerson!,
                    operation: operation,
                    date: dateCtrl.text.trim(),
                    vehicle: carCtrl.text.trim(),
                    driver: driverCtrl.text.trim(),
                    item: itemCtrl.text.trim(),
                    weight: weight,
                    price: price,
                    total: total,
                    notes: notesCtrl.text.trim(),
                  );

                  await supabase
                      .from('trips')
                      .insert(newTrip.toMap());
                }

                // ==================================================
                // نجاح العملية
                // ==================================================

                if (!mounted) return;

                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor:
                        AppColors.receivableGreen,
                    content: Text(
                      isEdit
                          ? 'تم تعديل النقلة بنجاح'
                          : 'تم حفظ النقلة بنجاح',
                    ),
                  ),
                );

                await _loadData();
              } catch (e) {
                if (!mounted) return;

                setModalState(() {
                  isSaving = false;
                });

                _showError(
                  isEdit
                      ? 'تعذر تعديل النقلة'
                      : 'تعذر حفظ النقلة',
                  e,
                );
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                title: Text(
                  isEdit
                      ? 'تعديل نقلة'
                      : operation == 'purchase'
                          ? 'تسجيل نقلة شراء'
                          : 'تسجيل نقلة بيع',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                content: Form(
                  key: formKey,

                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // ==================================================
                        // التاريخ
                        // ==================================================

                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10),

                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),

                          title: Text(
                            'التاريخ: ${dateCtrl.text}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          trailing: const Icon(
                            Icons.calendar_month,
                            color: AppColors.primary,
                          ),

                          onTap: isSaving
                              ? null
                              : () async {
                                  final picked =
                                      await showDatePicker(
                                    context: dialogContext,
                                    initialDate: selectedDate,
                                    firstDate:
                                        DateTime(2020),
                                    lastDate:
                                        DateTime(2035),
                                  );

                                  if (picked != null) {
                                    setModalState(() {
                                      selectedDate =
                                          picked;

                                      dateCtrl.text =
                                          DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(picked);
                                    });
                                  }
                                },
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // الطرف
                        // ==================================================

                        DropdownButtonFormField<String>(
                          value: selectedPerson,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'اختر الطرف (العميل / المورد)',
                          ),

                          items: _persons
                              .map(
                                (p) =>
                                    DropdownMenuItem<String>(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                  ),
                                ),
                              )
                              .toList(),

                          onChanged: isSaving
                              ? null
                              : (v) {
                                  setModalState(() {
                                    selectedPerson = v;
                                  });
                                },

                          validator: (v) {
                            if (v == null ||
                                v.isEmpty) {
                              return 'يرجى اختيار الطرف';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // نوع العملية
                        // ==================================================

                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'purchase',
                              label: Text(
                                'شراء من مورد',
                              ),
                            ),
                            ButtonSegment(
                              value: 'sale',
                              label: Text(
                                'بيع لعميل',
                              ),
                            ),
                          ],

                          selected: {operation},

                          onSelectionChanged:
                              isSaving
                                  ? null
                                  : isOperationLocked
                                      ? (s) {
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'نوع العملية ثابت من هذه الشاشة ولا يمكن تغييره',
                                              ),
                                            ),
                                          );
                                        }
                                      : (s) {
                                          setModalState(() {
                                            operation =
                                                s.first;
                                          });
                                        },
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // الصنف
                        // ==================================================

                        TextFormField(
                          controller: itemCtrl,

                          enabled: !isSaving,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'نوع البضاعة (قمح، ذرة، فول...)',
                          ),

                          validator: (v) {
                            if (v == null ||
                                v.trim().isEmpty) {
                              return 'مطلوب';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // الوزن والسعر
                        // ==================================================

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: weightCtrl,

                                enabled: !isSaving,

                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'الوزن (طن)',
                                ),

                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),

                                validator: (v) {
                                  if (v == null ||
                                      v.trim().isEmpty) {
                                    return 'مطلوب';
                                  }

                                  final val =
                                      double.tryParse(
                                    v.trim(),
                                  );

                                  if (val == null ||
                                      val <= 0) {
                                    return 'قيمة غير صحيحة';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: TextFormField(
                                controller: priceCtrl,

                                enabled: !isSaving,

                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'سعر الطن (ج.م)',
                                ),

                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),

                                validator: (v) {
                                  if (v == null ||
                                      v.trim().isEmpty) {
                                    return 'مطلوب';
                                  }

                                  final val =
                                      double.tryParse(
                                    v.trim(),
                                  );

                                  if (val == null ||
                                      val <= 0) {
                                    return 'قيمة غير صحيحة';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // السيارة والسائق
                        // ==================================================

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: carCtrl,

                                enabled: !isSaving,

                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'التحميل (السيارة)',
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: TextFormField(
                                controller: driverCtrl,

                                enabled: !isSaving,

                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'اسم السائق',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // الملاحظات
                        // ==================================================

                        TextFormField(
                          controller: notesCtrl,

                          enabled: !isSaving,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'ملاحظات إضافية',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================================
                // أزرار النافذة
                // ==========================================================

                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.pop(ctx);
                          },
                    child: const Text('إلغاء'),
                  ),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : saveTrip,

                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ النقلة',
                          ),
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
  // بيع من نقلة شراء
  // ============================================================

  void _openSellPurchaseModal(TripModel purchase) {
    final status = _statuses[purchase.id] ?? '';

    double remaining = purchase.weight;

    if (status.startsWith('متبقي للبيع:')) {
      remaining = double.tryParse(
            status
                .replaceAll('متبقي للبيع:', '')
                .replaceAll('طن', '')
                .trim(),
          ) ??
          0.0;
    } else if (status == 'تم بيع الوزنة') {
      remaining = 0.0;
    }

    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'النقلة مباعة بالكامل بالفعل!',
          ),
          backgroundColor:
              AppColors.warningOrange,
        ),
      );

      return;
    }

    String? selectedCustomer;

    DateTime saleDate = DateTime.now();

    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(saleDate),
    );

    final weightCtrl = TextEditingController(
      text: remaining.toString(),
    );

    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isSaving = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16),
              ),

              title: const Text(
                'بيع ونقل من النقلة المشتراة',
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(8),

                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withOpacity(0.08),

                        borderRadius:
                            BorderRadius.circular(8),
                      ),

                      child: Text(
                        'الصنف: ${purchase.item} | '
                        'سيارة: ${purchase.vehicle}\n'
                        'المتاح للبيع: '
                        '${remaining.toStringAsFixed(2)} طن',

                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                        side: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),

                      title: Text(
                        'تاريخ البيع: ${dateCtrl.text}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      trailing: const Icon(
                        Icons.calendar_month,
                        color:
                            AppColors.receivableGreen,
                      ),

                      onTap: isSaving
                          ? null
                          : () async {
                              final picked =
                                  await showDatePicker(
                                context: context,
                                initialDate:
                                    saleDate,
                                firstDate:
                                    DateTime(2020),
                                lastDate:
                                    DateTime(2035),
                              );

                              if (picked != null) {
                                setModalState(() {
                                  saleDate = picked;

                                  dateCtrl.text =
                                      DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(picked);
                                });
                              }
                            },
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(
                        labelText:
                            'العميل المشتري',
                      ),

                      items: _persons
                          .map(
                            (p) =>
                                DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),

                      onChanged: isSaving
                          ? null
                          : (v) {
                              setModalState(() {
                                selectedCustomer =
                                    v;
                              });
                            },
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      controller: weightCtrl,

                      enabled: !isSaving,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'الوزن المباع (طن)',
                      ),

                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      controller: priceCtrl,

                      enabled: !isSaving,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'سعر بيع الطن (ج.م)',
                      ),

                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final w =
                              double.tryParse(
                                    weightCtrl.text
                                        .trim(),
                                  ) ??
                                  0;

                          final p =
                              double.tryParse(
                                    priceCtrl.text
                                        .trim(),
                                  ) ??
                                  0;

                          if (selectedCustomer ==
                                  null ||
                              w <= 0 ||
                              p <= 0) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'يرجى ملء جميع الحقول بصورة صحيحة',
                                ),
                              ),
                            );

                            return;
                          }

                          if (w >
                              remaining + 0.0001) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'الوزن المطلوب بيعه أكبر من الكمية المتاحة!',
                                ),
                              ),
                            );

                            return;
                          }

                          final isAuthorized =
                              await SettingsScreen
                                  .verifyPassword(
                            context,
                          );

                          if (!isAuthorized) {
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                          });

                          try {
                            final totalSale = w * p;

                            final supabase =
                                Supabase.instance.client;

                            final saleTrip =
                                TripModel(
                              id: const Uuid().v4(),
                              personId:
                                  selectedCustomer!,
                              operation: 'sale',
                              date: dateCtrl.text,
                              vehicle:
                                  purchase.vehicle,
                              driver:
                                  purchase.driver,
                              item: purchase.item,
                              weight: w,
                              price: p,
                              total: totalSale,
                              sourceTripId:
                                  purchase.id,
                            );

                            await supabase
                                .from('trips')
                                .insert(
                                  saleTrip.toMap(),
                                );

                            if (!mounted) return;

                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                backgroundColor:
                                    AppColors
                                        .receivableGreen,
                                content: Text(
                                  'تم تسجيل عملية البيع بنجاح',
                                ),
                              ),
                            );

                            await _loadData();
                          } catch (e) {
                            setModalState(() {
                              isSaving = false;
                            });

                            _showError(
                              'تعذر تسجيل عملية البيع',
                              e,
                            );
                          }
                        },

                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'تأكيد عملية البيع',
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // لون الحالة
  // ============================================================

  Color _getStatusColor(String status) {
    if (status.contains('تم بيع') ||
        status.contains('تم شراء')) {
      return AppColors.receivableGreen;
    }

    if (status.contains('متبقي')) {
      return AppColors.warningOrange;
    }

    return AppColors.payableRed;
  }

  // ============================================================
  // الواجهة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _trips.where((t) {
      if (widget.initialOperation != null &&
          t.operation != widget.initialOperation) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final q =
          _searchQuery.trim().toLowerCase();

      return t.personName
              .toLowerCase()
              .contains(q) ||
          t.item.toLowerCase().contains(q) ||
          t.vehicle.toLowerCase().contains(q) ||
          t.driver.toLowerCase().contains(q);
    }).toList();

    String appBarTitle =
        'سجل النقلات والوزنات';

    if (widget.initialOperation ==
        'purchase') {
      appBarTitle = 'سجل نقلات الشراء';
    }

    if (widget.initialOperation == 'sale') {
      appBarTitle = 'سجل نقلات البيع';
    }

    return Directionality(
      textDirection: TextDirection.rtl,

      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),

          bottom: PreferredSize(
            preferredSize:
                const Size.fromHeight(56),

            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),

              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(10),
                ),

                child: TextField(
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                    });
                  },

                  decoration:
                      const InputDecoration(
                    hintText:
                        'بحث باسم الطرف، الصنف، السيارة، السائق...',

                    prefixIcon: Icon(
                      Icons.search,
                      color:
                          AppColors.primary,
                    ),

                    border: InputBorder.none,

                    enabledBorder:
                        InputBorder.none,

                    focusedBorder:
                        InputBorder.none,

                    contentPadding:
                        EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ========================================================
        // إضافة نقلة
        // ========================================================

        floatingActionButton:
            FloatingActionButton(
          backgroundColor:
              AppColors.primary,

          foregroundColor:
              Colors.white,

          onPressed: () {
            openTripDialog(
              preselectedOperation:
                  widget.initialOperation,
            );
          },

          child: const Icon(Icons.add),
        ),

        // ========================================================
        // المحتوى
        // ========================================================

        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : filteredTrips.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد نقلات مسجلة حالياً',
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 8,
                    ),

                    itemCount:
                        filteredTrips.length,

                    itemBuilder: (ctx, i) {
                      final t =
                          filteredTrips[i];

                      final isSale =
                          t.operation == 'sale';

                      final status =
                          _statuses[t.id] ?? '';

                      return Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      color: isSale
                                          ? const Color(
                                              0xFFDCFCE7,
                                            )
                                          : const Color(
                                              0xFFFEF3C7,
                                            ),

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        6,
                                      ),
                                    ),

                                    child: Text(
                                      isSale
                                          ? 'بيع لعميل'
                                          : 'شراء من مورد',

                                      style:
                                          TextStyle(
                                        color: isSale
                                            ? const Color(
                                                0xFF166534,
                                              )
                                            : const Color(
                                                0xFF92400E,
                                              ),

                                        fontWeight:
                                            FontWeight
                                                .bold,

                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 8,
                                  ),

                                  Expanded(
                                    child: Text(
                                      t.personName,

                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        fontSize: 15,
                                      ),

                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ),

                                  Text(
                                    t.date,

                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color: AppColors
                                          .textSecondary,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,

                                children: [
                                  Text(
                                    'الصنف: ${t.item}',

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                      fontSize: 13,
                                    ),
                                  ),

                                  Text(
                                    '${t.weight.toStringAsFixed(2)} طن × '
                                    '${t.price.toStringAsFixed(2)} ج.م',

                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color: AppColors
                                          .textSecondary,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              Text(
                                'الإجمالي: '
                                '${AppFormatters.formatCurrency(t.total)}',

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors
                                      .primaryDark,
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              if (t.vehicle.isNotEmpty ||
                                  t.driver.isNotEmpty)
                                Align(
                                  alignment:
                                      Alignment
                                          .centerLeft,

                                  child: Text(
                                    'سيارة: ${t.vehicle} | '
                                    '${t.driver}',

                                    style:
                                        const TextStyle(
                                      fontSize: 11,
                                      color: AppColors
                                          .textSecondary,
                                    ),
                                  ),
                                ),

                              const Divider(
                                height: 16,
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,

                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _getStatusColor(
                                        status,
                                      ).withOpacity(
                                        0.12,
                                      ),

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        4,
                                      ),
                                    ),

                                    child: Text(
                                      status,

                                      style:
                                          TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        color:
                                            _getStatusColor(
                                          status,
                                        ),
                                      ),
                                    ),
                                  ),

                                  Row(
                                    children: [
                                      if (!isSale)
                                        IconButton(
                                          icon:
                                              const Icon(
                                            Icons
                                                .sell_outlined,
                                            color:
                                                AppColors
                                                    .primary,
                                            size: 20,
                                          ),

                                          tooltip:
                                              'بيع ونقل مباشر لعميل',

                                          onPressed: () =>
                                              _openSellPurchaseModal(
                                            t,
                                          ),
                                        ),

                                      IconButton(
                                        icon:
                                            const Icon(
                                          Icons
                                              .edit_outlined,
                                          color: AppColors
                                              .textSecondary,
                                          size: 20,
                                        ),

                                        tooltip:
                                            'تعديل',

                                        onPressed: () =>
                                            openTripDialog(
                                          existing: t,
                                        ),
                                      ),

                                      IconButton(
                                        icon:
                                            const Icon(
                                          Icons
                                              .delete_outline,
                                          color: AppColors
                                              .payableRed,
                                          size: 20,
                                        ),

                                        tooltip:
                                            'حذف',

                                        onPressed:
                                            () async {
                                          final isAuthorized =
                                              await SettingsScreen
                                                  .verifyPassword(
                                            context,
                                          );

                                          if (!isAuthorized) {
                                            return;
                                          }

                                          if (!mounted) {
                                            return;
                                          }

                                          final confirmed =
                                              await showDialog<
                                                  bool>(
                                            context:
                                                context,

                                            builder:
                                                (ctx) =>
                                                    Directionality(
                                              textDirection:
                                                  TextDirection
                                                      .rtl,

                                              child:
                                                  AlertDialog(
                                                title:
                                                    const Text(
                                                  'تأكيد الحذف',
                                                ),

                                                content:
                                                    Text(
                                                  'هل تريد حذف هذه النقلة؟\n\n'
                                                  '${t.item} - '
                                                  '${t.weight.toStringAsFixed(2)} طن',
                                                ),

                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () =>
                                                            Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                    child:
                                                        const Text(
                                                      'إلغاء',
                                                    ),
                                                  ),

                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.payableRed,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),

                                                    onPressed:
                                                        () =>
                                                            Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),

                                                    child:
                                                        const Text(
                                                      'حذف',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );

                                          if (confirmed !=
                                              true) {
                                            return;
                                          }

                                          try {
                                            final supabase =
                                                Supabase
                                                    .instance
                                                    .client;

                                            await supabase
                                                .from(
                                                    'trips')
                                                .delete()
                                                .eq(
                                                  'id',
                                                  t.id,
                                                );

                                            if (!mounted) {
                                              return;
                                            }

                                            ScaffoldMessenger
                                                .of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                backgroundColor:
                                                    AppColors
                                                        .receivableGreen,
                                                content:
                                                    Text(
                                                  'تم حذف النقلة بنجاح',
                                                ),
                                              ),
                                            );

                                            await _loadData();
                                          } catch (e) {
                                            _showError(
                                              'تعذر حذف النقلة',
                                              e,
                                            );
                                          }
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
