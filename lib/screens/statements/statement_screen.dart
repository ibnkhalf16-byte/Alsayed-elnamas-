import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/accounting/accounting_engine.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../../core/pdf/pdf_generator.dart';

class StatementScreen extends StatefulWidget {
  final PersonModel? initialPerson;

  const StatementScreen({
    super.key,
    this.initialPerson,
  });

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  bool _generatingPdf = false;

  List<PersonModel> _persons = [];
  List<TripModel> _trips = [];
  List<PaymentModel> _payments = [];

  PersonModel? _selectedPerson;

  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final personsData = await supabase
          .from('persons')
          .select()
          .order('name', ascending: true);

      final tripsData = await supabase
          .from('trips')
          .select();

      final paymentsData = await supabase
          .from('payments')
          .select();

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

      if (widget.initialPerson != null) {
        final matching = persons.where(
          (p) => p.id == widget.initialPerson!.id,
        );

        if (matching.isNotEmpty) {
          _selectedPerson = matching.first;
        } else {
          _selectedPerson = widget.initialPerson;
        }

        await _fetchStatement();
      }
    } catch (e, stackTrace) {
      debugPrint('Statement load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        'تعذر تحميل كشف الحساب:\n$e',
      );
    }
  }

  Future<void> _fetchStatement() async {
    final person = _selectedPerson;

    if (person == null) {
      setState(() {
        _events = [];
      });
      return;
    }

    try {
      final events = AccountingEngine.calculateStatement(
        person,
        _trips,
        _payments,
      );

      if (!mounted) return;

      setState(() {
        _events = events;
      });
    } catch (e, stackTrace) {
      debugPrint('Statement calculation error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _events = [];
      });

      _showError(
        'تعذر حساب كشف الحساب:\n$e',
      );
    }
  }

  Future<void> _generatePdf() async {
    final person = _selectedPerson;

    if (person == null) {
      _showError('يرجى اختيار طرف أولاً.');
      return;
    }

    if (_generatingPdf) return;

    setState(() {
      _generatingPdf = true;
    });

    try {
      await PdfGenerator.generateAndPrintStatement(
        person: person,
        events: _events,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تجهيز كشف الحساب بنجاح',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Generate PDF error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showError(
        'تعذر إنشاء ملف PDF:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
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
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
  }

  @override
  Widget build(BuildContext context) {
    final lastBalance = _events.isNotEmpty
        ? ((_events.last['balance'] as num?)?.toDouble() ?? 0.0)
        : (_selectedPerson == null
            ? 0.0
            : _selectedPerson!.openingReceivable -
                _selectedPerson!.openingPayable);

    final isReceivable = lastBalance > 0;
    final isPayable = lastBalance < 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف الحساب'),
          actions: [
            if (_selectedPerson != null)
              _generatingPdf
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _generatePdf,
                      tooltip: 'تصدير PDF',
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                      ),
                    ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<PersonModel>(
                      value: _selectedPerson,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'اختر الطرف',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: _persons.map((person) {
                        return DropdownMenuItem<PersonModel>(
                          value: person,
                          child: Text(
                            person.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (person) async {
                        setState(() {
                          _selectedPerson = person;
                          _events = [];
                        });

                        await _fetchStatement();
                      },
                    ),
                  ),

                  if (_selectedPerson != null)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPerson!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    lastBalance.abs() < 0.01
                                        ? 'الرصيد متزن'
                                        : isReceivable
                                            ? 'لنا: ${_formatMoney(lastBalance.abs())}'
                                            : isPayable
                                                ? 'علينا: ${_formatMoney(lastBalance.abs())}'
                                                : 'الرصيد متزن',
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
                            ),
                          ],
                        ),
                      ),
                    ),

                  Expanded(
                    child: _selectedPerson == null
                        ? const Center(
                            child: Text(
                              'اختر طرفًا لعرض كشف الحساب',
                            ),
                          )
                        : _events.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد حركات لهذا الطرف',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _events.length,
                                itemBuilder: (context, index) {
                                  final event = _events[index];

                                  final date =
                                      event['date']?.toString() ?? '';

                                  final description =
                                      event['description']
                                              ?.toString() ??
                                          event['title']
                                              ?.toString() ??
                                          '';

                                  final balance =
                                      (event['balance'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                  final debit =
                                      (event['debit'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                  final credit =
                                      (event['credit'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                  return Card(
                                    margin: const EdgeInsets.only(
                                      bottom: 8,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        description,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        date,
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (debit != 0)
                                            Text(
                                              'مدين: ${_formatMoney(debit)}',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          if (credit != 0)
                                            Text(
                                              'دائن: ${_formatMoney(credit)}',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          Text(
                                            'الرصيد: ${_formatMoney(balance)}',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
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
