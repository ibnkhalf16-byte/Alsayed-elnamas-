import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
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
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('persons', orderBy: 'name ASC');
    final pList = maps.map((m) => PersonModel.fromMap(m)).toList();

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

  Future<void> _fetchStatement(PersonModel person) async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final tMaps = await db.query('trips');
    final pMaps = await db.query('payments');

    final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final payments = pMaps.map((m) => PaymentModel.fromMap(m)).toList();

    final statementEvents = AccountingEngine.calculateStatement(person, trips, payments);

    setState(() {
      _selectedPerson = person;
      _events = statementEvents;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lastBalance = _events.isNotEmpty ? (_events.last['balance'] as double) : 0.0;
    final isReceivable = lastBalance >= 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف الحساب المالي'),
          actions: [
            if (_selectedPerson != null && _events.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'طباعة وتصدير PDF',
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
              padding: const EdgeInsets.all(12.0),
              child: DropdownButtonFormField<PersonModel>(
                value: _selectedPerson,
                decoration: const InputDecoration(labelText: 'اختر الطرف لعرض كشف الحساب'),
                items: _persons
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) {
                  if (p != null) _fetchStatement(p);
                },
              ),
            ),
            if (_selectedPerson != null && _events.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isReceivable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الرصيد النهائي: ${AppFormatters.formatCurrency(lastBalance.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                      ),
                    ),
                    Text(
                      isReceivable ? 'مستحق (لك عنده)' : 'مطلوب (له عندك)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد حركات مسجلة لهذا الحساب',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) {
                            final ev = _events[i];
                            final debit = (ev['debit'] as num).toDouble();
                            final credit = (ev['credit'] as num).toDouble();
                            final balance = (ev['balance'] as num).toDouble();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${ev['type']} - ${ev['desc']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          ev['date'].toString(),
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'مدين (+): ${AppFormatters.formatCurrency(debit)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.receivableGreen),
                                        ),
                                        Text(
                                          'دائن (-): ${AppFormatters.formatCurrency(credit)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.payableRed),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 12),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'الرصيد بعد الحركة: ${AppFormatters.formatCurrency(balance)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
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
