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

  const StatementScreen({Key? key, this.initialPerson}) : super(key: key);

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  List<PersonModel> _persons = [];
  PersonModel? _selectedPerson;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final supabase = Supabase.instance.client;
      final maps = await supabase.from('persons').select().order('name', ascending: true);
      final pList = maps.map((m) => PersonModel.fromMap(m)).toList();

      if (mounted) {
        setState(() {
          _persons = pList;
          _isLoading = false;
          if (widget.initialPerson != null) {
            _selectedPerson = _persons.firstWhere(
              (p) => p.id == widget.initialPerson!.id,
              orElse: () => widget.initialPerson!,
            );
            _fetchStatement(_selectedPerson!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الأطراف: $e')));
      }
    }
  }

  Future<void> _fetchStatement(PersonModel person) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final tMaps = await supabase.from('trips').select();
      final pMaps = await supabase.from('payments').select();

      final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
      final payments = pMaps.map((m) => PaymentModel.fromMap(m)).toList();

      final statementEvents = AccountingEngine.calculateStatement(person, trips, payments);

      if (mounted) {
        setState(() {
          _selectedPerson = person;
          _events = statementEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الحركات: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastBalance = _events.isNotEmpty ? (_events.last['balance'] as double) : 0.0;
    final isReceivable = lastBalance >= 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف حساب مفصل'),
          actions: [
            if (_selectedPerson != null && _events.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'تصدير PDF',
                onPressed: () {
                  PdfGenerator.generateAndPrintStatement(
                    person: _selectedPerson!,
                    events: _events,
                  );
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<PersonModel>(
                value: _selectedPerson,
                decoration: const InputDecoration(
                  labelText: 'اختر الطرف (العميل أو المورد)',
                  prefixIcon: Icon(Icons.person),
                ),
                items: _persons
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) {
                  if (p != null) _fetchStatement(p);
                },
              ),
            ),
            if (_selectedPerson != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isReceivable 
                      ? [AppColors.receivableGreen.withOpacity(0.8), AppColors.receivableGreen]
                      : [AppColors.payableRed.withOpacity(0.8), AppColors.payableRed],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                     BoxShadow(
                       color: (isReceivable ? AppColors.receivableGreen : AppColors.payableRed).withOpacity(0.3),
                       blurRadius: 8,
                       offset: const Offset(0, 4)
                     )
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الرصيد النهائي الحالي:', style: TextStyle(color: Colors.white, fontSize: 14)),
                        Text(
                          AppFormatters.formatCurrency(lastBalance.abs()),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isReceivable ? 'مستحق (لك عنده)' : 'مطلوب (له عندك)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد حركات مسجلة لهذا الحساب',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) {
                            final ev = _events[i];
                            final debit = (ev['debit'] as num).toDouble();
                            final credit = (ev['credit'] as num).toDouble();
                            final balance = (ev['balance'] as num).toDouble();
                            final isOpening = ev['type'] == 'رصيد افتتاح';

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isOpening ? AppColors.primary.withOpacity(0.05) : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isOpening ? Icons.account_balance : (debit > 0 ? Icons.add_circle : Icons.remove_circle),
                                              color: isOpening ? AppColors.primary : (debit > 0 ? AppColors.receivableGreen : AppColors.payableRed),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${ev['type']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 15,
                                                color: isOpening ? AppColors.primary : AppColors.textPrimary
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          ev['date'].toString(),
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'البيان: ${ev['desc']}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('مدين (+): ${AppFormatters.formatCurrency(debit)}', style: const TextStyle(color: AppColors.receivableGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                                            Text('دائن (-): ${AppFormatters.formatCurrency(credit)}', style: const TextStyle(color: AppColors.payableRed, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.scaffoldBackground,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'الرصيد: ${AppFormatters.formatCurrency(balance)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.primaryDark,
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
